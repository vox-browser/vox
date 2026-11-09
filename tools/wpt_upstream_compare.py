#!/usr/bin/env python3
"""Run every testharness variant in an official WPT manifest through Vox.

This does not execute reftests, WebDriver tests, manual tests or other manifest
types. Unsupported protocols remain explicit failed records in the selection.
Run under tools/run_memory_bounded.py; browser processes retain the imported
runner's 4 GiB cap, fresh profiles and original harness deadlines.
"""
import argparse
import contextlib
import hashlib
import importlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
from urllib.parse import parse_qs, urlsplit

import wpt_compare as compare
from browser_bundle_lease import canonical_bundle_lease
from wpt_inventory import inventory_manifest, manifest_leaves
from wpt_upstream_server import UpstreamWPTServer


def manifest_cases(manifest):
    """Retain generated worker/window URLs, queries and manifest timeouts."""
    inventory, _ = inventory_manifest(manifest)
    cases = []
    seen = set()
    for path, variants in manifest_leaves(manifest['items'].get('testharness', {})):
        for relative, metadata in variants:
            if not isinstance(metadata, dict) or metadata.get('timeout') not in (None, 'long'):
                raise ValueError(f'Invalid testharness metadata: {path}')
            if relative is not None and relative.startswith('/'):
                raise ValueError(f'Manifest URLs must be relative to the root: {relative}')
            url = '/' + (relative if relative is not None else path)
            parsed = urlsplit(url)
            if parsed.netloc or parsed.scheme or parsed.fragment or not parsed.path.startswith('/') \
                    or '..' in parsed.path.split('/') or url in seen:
                raise ValueError(f'Invalid or duplicate manifest URL: {url}')
            seen.add(url)
            flags = set(parsed.path.rsplit('/', 1)[-1].split('.')[1:-1])
            flags.update(parse_qs(parsed.query).get('wpt_flags', []))
            secure = bool(flags & {'https', 'serviceworker', 'serviceworker-module'})
            cases.append(dict(id=url, url=url, path=path,
                              harness_timeout=60 if metadata.get('timeout') == 'long' else 10,
                              protocol='h2' if 'h2' in flags else 'https' if secure else 'http',
                              subdomain='www' if 'www' in flags else None))
    cases.sort(key=lambda case: case['id'])
    if len(cases) != inventory['types'].get('testharness', {}).get('test_variants', 0):
        raise ValueError('Manifest variant count mismatch')
    return cases, inventory


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args])


def checkout_identity(root, manifest):
    """Reject stale manifests as well as modified source/support resources."""
    revision = git(root, 'rev-parse', 'HEAD').decode().strip()
    if git(root, 'status', '--porcelain', '--untracked-files=no').strip():
        raise ValueError('Upstream WPT tracked inputs are modified')
    blobs = {}
    for entry in git(root, 'ls-files', '--stage', '-z').split(b'\0'):
        if not entry:
            continue
        info, path = entry.split(b'\t', 1)
        _, digest, stage = info.split()
        if stage != b'0':
            raise ValueError('Upstream WPT index has unresolved entries')
        blobs[path.decode()] = digest.decode()
    for tree in manifest['items'].values():
        for path, _ in manifest_leaves(tree):
            leaf = tree
            for part in path.split('/'):
                leaf = leaf[part]
            if blobs.get(path) != leaf[0]:
                raise ValueError(f'Manifest does not match upstream Git inputs: {path}')
    return dict(root=str(root), revision=revision, tracked_files=len(blobs))


def verify_checkout(root, identity):
    if git(root, 'rev-parse', 'HEAD').decode().strip() != identity['revision'] \
            or git(root, 'status', '--porcelain', '--untracked-files=no').strip():
        raise compare.RunAborted('Upstream WPT checkout changed')


class ManifestServer(UpstreamWPTServer):
    """Install upstream's generated .any/.worker/.window routes before launch."""
    def __init__(self, *args):
        super().__init__(*args)
        try:
            serve = importlib.import_module('serve.serve')
            routes = serve.RoutesBuilder().get_routes()
            # No browser has been launched yet. Keep the recording router and
            # collector interception while replacing its default static routes.
            for httpd in self.servers:
                httpd.router.routes.clear()
                for route in reversed(routes):
                    httpd.router.register(*route)
                for rewrite in serve.rewrites:
                    httpd.rewriter.register(*rewrite)
            self.identity['generated_routes'] = 'official tools/serve/serve.py RoutesBuilder'
            self.identity['source_files'] = self.source_hashes()
        except BaseException:
            self.shutdown()
            raise


def origin_url(case, server):
    if case['protocol'] == 'h2':
        raise ValueError('HTTP/2 is not served by this adapter')
    scheme = case['protocol']
    port = server.identity[scheme + '_ports'][0]
    host = ('www.' if case['subdomain'] else '') + server.identity['host']
    return f'{scheme}://{host}:{port}' + case['url']


def select_cases(cases, includes, offset, limit):
    prefixes = ['/' + prefix.lstrip('/') for prefix in includes]
    selected = [case for case in cases if not prefixes or any(
        case['id'] == prefix or case['id'].partition('?')[0] == prefix
        or case['id'].startswith(prefix.rstrip('/') + '/') for prefix in prefixes)]
    return selected[offset:] if limit is None else selected[offset:offset + limit]


def run(args, cases, inventory, upstream, manifest_hash):
    args.output.mkdir(parents=True, exist_ok=False)
    (args.output / 'logs').mkdir()
    (args.output / 'profiles').mkdir()
    executable = args.vox.resolve()
    pins = {str(path): compare.sha256(path) for path in executable.parent.iterdir() if path.is_file()}
    for name in ['wpt_upstream_compare.py', 'wpt_inventory.py', 'wpt_compare.py',
                 'wpt_upstream_server.py', 'browser_bundle_lease.py', 'run_memory_bounded.py']:
        path = Path(__file__).parent / name
        pins[str(path)] = compare.sha256(path)
    pins[str(args.manifest)] = manifest_hash
    identity = dict(scope='official upstream manifest testharness; excludes other test types',
                    full_upstream_wpt=False, upstream=upstream, inventory=inventory,
                    selected_cases=len(cases), manifest_sha256=manifest_hash,
                    include=args.include, offset=args.offset, limit=args.limit,
                    argv=sys.argv, started=time.strftime('%Y-%m-%dT%H:%M:%S%z'),
                    host_cpus=os.cpu_count(), load_start=os.getloadavg(), pinned=pins,
                    changed_inputs=[], aborted=None, browser_memory_gib=4,
                    unsupported_protocols=['h2', 'ws', 'wss', 'webtransport-h3'])
    records, chunks = [], []
    server = None
    with (args.output / 'requests.log').open('w', buffering=1) as request_log, \
            (args.output / 'results.jsonl').open('w', buffering=1) as results:
        runner = compare.Runner(request_log)
        written = 0
        try:
            resources = {
                '/resources/testharnessreport.js': (compare.REPORT_SCRIPT.encode(), 'text/javascript'),
                compare.WARMUP['url']: (compare.WARMUP_PAGE, 'text/html')}
            # The official upstream testharness.js is served byte-for-byte.
            server = ManifestServer(args.wpt_root, args.wpt_root, runner, resources,
                                    compare.RUNNER_PREFIX + 'alive', compare.RUNNER_PREFIX + 'result',
                                    args.output / 'certificates')
            identity['server'] = server.identity
            pins[server.identity['ca_certificate']] = server.identity['ca_sha256']
            # Trust only this job's private CA; no OS trust settings change.
            with contextlib.ExitStack() as environment:
                before = os.environ.get('SSL_CERT_FILE')
                def restore_ca():
                    if before is None:
                        os.environ.pop('SSL_CERT_FILE', None)
                    else:
                        os.environ['SSL_CERT_FILE'] = before
                environment.callback(restore_ca)
                os.environ['SSL_CERT_FILE'] = server.identity['ca_certificate']
                (args.output / 'tests.json').write_text(json.dumps(cases, indent=1) + '\n')
                for index, chunk in enumerate(compare.chunks_of(cases, args.chunk_size)):
                    verify_checkout(args.wpt_root, upstream)
                    changed = [p for p, h in pins.items() if not Path(p).is_file() or compare.sha256(Path(p)) != h]
                    changed.extend(server.changed_inputs())
                    if changed:
                        identity['changed_inputs'] = changed
                        raise compare.RunAborted('Pinned runner/browser/manifest inputs changed')
                    runnable = []
                    for case in chunk:
                        if case['protocol'] == 'h2':
                            records.append(dict(browser='vox', test=case['id'], outcome='UNSUPPORTED_PROTOCOL',
                                                harness=None, subtests=[], protocol='h2'))
                        else:
                            runnable.append(dict(case, url=origin_url(case, server)))
                    if runnable:
                        chunks.append(compare.run_chunk(runner, 'vox', executable, pins[str(executable)],
                                                        runnable, records, server.base_url, args.output,
                                                        index, 1024, 768, compare.Limits()))
                    for record in records[written:]:
                        results.write(json.dumps(record) + '\n')
                    written = len(records)
                    print(f'Completed {written}/{len(cases)} selected variants', flush=True)
        except (compare.RunAborted, ValueError) as error:
            identity['aborted'] = str(error)
        finally:
            for record in records[written:]:
                results.write(json.dumps(record) + '\n')
            if server is not None:
                identity['changed_inputs'].extend(server.changed_inputs())
                server.shutdown()
    try:
        verify_checkout(args.wpt_root, upstream)
    except compare.RunAborted as error:
        identity['aborted'] = str(error)
    identity['changed_inputs'] = sorted(set(identity['changed_inputs']) | {
        p for p, h in pins.items() if not Path(p).is_file() or compare.sha256(Path(p)) != h})
    identity.update(finished=time.strftime('%Y-%m-%dT%H:%M:%S%z'), load_end=os.getloadavg(),
                    unexpected_posts=runner.unexpected_posts)
    summary = compare.summarize(cases, records, chunks)
    summary.update(scope=identity['scope'], full_upstream_wpt=False,
                   all_selected_cases_pass=bool(not identity['aborted'] and not identity['changed_inputs']
                                               and compare.suite_passes(cases, records, ['vox'])))
    for name, value in [('identity', identity), ('summary', summary), ('chunks', chunks)]:
        (args.output / (name + '.json')).write_text(json.dumps(value, indent=1) + '\n')
    print(json.dumps(summary, indent=1))
    return 0 if summary['all_selected_cases_pass'] else 1


def main():
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--wpt-root', type=Path, required=True)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--vox', type=Path, default=compare.VOX)
    parser.add_argument('--include', action='append', default=[])
    parser.add_argument('--offset', type=int, default=0)
    parser.add_argument('--limit', type=int)
    parser.add_argument('--chunk-size', type=int, default=100)
    args = parser.parse_args()
    if args.offset < 0 or args.chunk_size < 1 or (args.limit is not None and args.limit < 1):
        parser.error('offset must be nonnegative; limit and chunk-size must be positive')
    args.wpt_root = args.wpt_root.resolve()
    args.manifest = args.manifest.resolve()
    data = args.manifest.read_bytes()
    manifest = json.loads(data)
    cases, inventory = manifest_cases(manifest)
    upstream = checkout_identity(args.wpt_root, manifest)
    cases = select_cases(cases, args.include, args.offset, args.limit)
    if not cases or not args.vox.is_file() or args.output.exists():
        parser.error('selection must be nonempty, browser must exist and output must be new')
    with canonical_bundle_lease(args.vox.resolve().parents[2]):
        return run(args, cases, inventory, upstream, hashlib.sha256(data).hexdigest())


if __name__ == '__main__':
    sys.exit(main())
