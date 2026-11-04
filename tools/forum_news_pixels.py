#!/usr/bin/env python3
"""Compare registered forum/news sites sequentially with Brave and full uBlock Origin.

Use --capture to freeze a new guest-page workload; normal runs replay sealed
fixtures without forwarding network requests. Zero differing RGBA pixels are
required. Access failures, missing fixtures and references that vary within or
between fresh Brave processes fail.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import threading
import time
from urllib.parse import urlsplit

from check_pixel_equality import compare
from page_archive import Replay, digest, load_archive

REPO = Path(__file__).resolve().parents[1]
CATALOG = REPO / 'Tests/Browser/Brave/forum-news.json'
HARNESS = REPO / 'tools/adblock/brave_parity.mjs'
BRAVE = Path('/Applications/Brave Browser.app/Contents/MacOS/Brave Browser')
VOX = REPO / 'Build/v/Vox.app/Contents/MacOS/Vox'
# C-optimized builds without V's -prod load $embed_file payloads from the
# checkout. Pin these alongside the bundle, including the worker's sources.
VOX_RUNTIME_ASSETS = (
    'adblock/engine.js.gz', 'adblock/engine.snapshot.bin',
    'adblock/engine.snapshot.json.gz', 'adblock/extended/procedural.js',
    'url/public_suffix_list_reversed.dat',
    'browserjs/vendor/es-module-lexer-1.7.0/lexer.asm.js',
    'browserhistory/history.css', 'aria/aria_roles.json',
    'dom/resources/pdfjs/viewer.html',
    'optimizedsites/assets/wikipedia.ico', 'optimizedsites/assets/reddit.png',
    'optimizedsites/assets/vlang.png', 'optimizedsites/assets/hacker-news.ico',
    'layout/resources/chromium/broken-image-200.png',
    'layout/resources/chromium/broken-image-100.png',
    'css/ua_default.css', 'css/ua_quirks_mode.css',
    'css/ua_mathml_default.css', 'css/ua_svg_default.css', 'html/media_controls.css',
)
VOX_BUNDLED_ADBLOCK_ASSETS = {
    'adblock/engine.snapshot.bin': 'adblock.snapshot.bin',
    'adblock/engine.snapshot.json.gz': 'adblock.engine.snapshot.json.gz',
    'adblock/engine.js.gz': 'adblock.engine.js.gz',
}


def read_json(path):
    return json.loads(path.read_text())


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n')


def check_filters(report, document=True):
    counts = report.get('counts', {})
    requests = report.get('requests', [])
    valid_counts = all(type(counts.get(key)) is int and counts[key] >= 0
                       for key in ['requests', 'blocked', 'allowed', 'mismatches', 'oracle_disagreements'])
    if (not valid_counts or not counts.get('requests') or counts.get('mismatches') != 0
            or counts.get('oracle_disagreements') != 0
            or counts['blocked'] + counts['allowed'] != counts['requests']
            or len(requests) != counts['requests']
            or report.get('common_stream', {}).get('matches') is not True
            or any(r.get('actual', {}).get('error') or any(
                type(r.get(side, {}).get(key)) is not bool
                for side in ['actual', 'expected'] for key in ['blocked', 'exception'])
                or any(r.get('actual', {}).get(key) != r.get('expected', {}).get(key)
                       for key in ['blocked', 'exception']) for r in requests)):
        raise RuntimeError('Full-uBO request/header comparison failed')
    if document:
        if report.get('navigation', {}).get('coverage') != 'page':
            raise RuntimeError('Requested site did not load: ' + str(report.get('navigation')))
        if not all(report.get('cosmetic', {}).get(key) is True for key in
                   ['css_matches', 'procedural_matches', 'scriptlet_filters_match']):
            raise RuntimeError('Full-uBO cosmetic/procedural/scriptlet comparison failed')


def seal_capture(capture, archive, report_file):
    """Import only bytes actually captured by full uBO; never fetch a gap."""
    report = read_json(report_file)
    check_filters(report)
    metadata = read_json(capture / 'archive.json')
    if metadata['url'] != report['navigation']['url']:
        raise RuntimeError('Capture and navigation identities differ')
    frozen = (capture / 'frozen.html').read_bytes()
    if digest(frozen) != metadata['frozen_html_sha256']:
        raise RuntimeError('Frozen document changed')
    archive.mkdir(parents=True, exist_ok=False)
    (archive / 'bodies').mkdir()
    entries = {}
    for resource in metadata['resources']:
        if resource.get('error'):
            continue
        url = resource['url']
        source = capture / 'cache/resources' / digest(url.encode())
        body = source.read_bytes()
        expected = metadata['frozen_html_sha256'] if url == metadata['url'] else resource['sha256']
        if digest(body) != expected:
            raise RuntimeError('Captured resource changed: ' + url)
        headers = read_json(Path(str(source) + '.headers.json'))
        if url == metadata['url']:
            headers = [h for h in headers if h['name'].lower() != 'content-type']
            headers.append(dict(name='Content-Type', value='text/html;charset=utf-8'))
        sha = digest(body)
        (archive / 'bodies' / sha).write_bytes(body)
        entries[url] = dict(status=200, headers=headers, sha256=sha, bytes=len(body))
    if metadata['url'] not in entries:
        raise RuntimeError('Missing main document')
    # Keep the complete full-uBO evidence, including the engine and list hashes.
    write_json(archive / 'capture.json', report)
    shutil.copyfile(capture / 'live.png', archive / 'live.png')
    write_json(archive / 'manifest.json', dict(version=1, url=metadata['url'],
        source_document_request_method=metadata.get('document_request_method', 'GET'),
        sealed_unix=time.time(), responses=entries, workload='Frozen guest DOM; scripts removed; original resource bytes',
        live_png_sha256=digest((archive / 'live.png').read_bytes()),
        capture_report_sha256=digest((archive / 'capture.json').read_bytes())))
    load_archive(archive)


def executable_identity(binary):
    paths = [binary, *sorted(binary.parent.glob('*.dylib'))]
    snapshot = binary.parent.parent / 'Resources/adblock.snapshot.bin'
    if snapshot.is_file():
        paths.append(snapshot)
    if binary.name == 'Vox':
        helper = binary.parent / 'VoxAdblockWorker'
        if helper.is_file():
            paths.append(helper)
        for name in VOX_RUNTIME_ASSETS:
            packaged = VOX_BUNDLED_ADBLOCK_ASSETS.get(name)
            resource = binary.parent.parent / 'Resources' / packaged if packaged else None
            if resource and resource.is_file():
                paths.append(resource)
            elif (REPO / name).is_file():
                paths.append(REPO / name)
    return {str(p.resolve()): digest(p.read_bytes()) for p in paths}


def brave_identity(binary):
    identity = executable_identity(binary)
    frameworks = binary.parent.parent / 'Frameworks'
    paths = set(frameworks.rglob('*'))
    # Keep the active-version alias as well: an update can retarget Current
    # while both old and new version directories remain on disk.
    paths.update(f / 'Versions/Current' / f.stem for f in frameworks.glob('*.framework'))
    macho = {bytes.fromhex(magic) for magic in
             ['feedface', 'cefaedfe', 'feedfacf', 'cffaedfe',
              'cafebabe', 'bebafeca', 'cafebabf', 'bfbafeca']}
    for path in sorted(paths):
        if path.is_file():
            with path.open('rb') as stream:
                native = stream.read(4) in macho
            if native:
                identity[str(path.absolute())] = digest(path.read_bytes())
    return identity


def native_capture_environment(profile, certificate, cache, audit, config, requests, settle):
    environment = {k: v for k, v in os.environ.items()
                   if not k.lower().endswith('_proxy') and not k.startswith(('VOX_', 'LADYBIRD_', 'DYLD_', 'GC_'))}
    # Compare the same full-uBO policy: Vox's additional banner blocker would
    # otherwise mutate the frozen guest DOM without an equivalent Brave rule.
    environment.update(VOX_PROFILE_DIR=str(profile), SSL_CERT_FILE=str(certificate),
        LADYBIRD_CACHE_DIR=str(cache), LADYBIRD_SCREENSHOT_SCALE='1',
        LADYBIRD_SCREENSHOT_DELAY_SECONDS=str(settle), VOX_CAPTURE_DOCUMENT_ONLY='1',
        VOX_TEST_WINDOW='1', VOX_CAPTURE_AUDIT_PATH=str(audit),
        VOX_CAPTURE_AUDIT_CONFIG=str(config), VOX_ADBLOCK_LOG=str(requests),
        VOX_BLOCK_COOKIE_BANNERS='0')
    return environment


def check_native(audit, reference):
    if (audit.get('url') != reference['url'] or audit.get('title') != reference['title']
            or audit.get('ready') != 'complete'
            or (audit.get('viewport_width'), audit.get('viewport_height')) != (1024, 768)):
        raise RuntimeError('Vox did not load the reference document at 1024x768')
    bodies = next((s['elements'] for s in audit.get('selections', []) if s['name'] == 'body'), [])
    if not bodies or len(bodies[0].get('text', '')) < 1000:
        raise RuntimeError('Vox body content is missing')


def warm_native_cache(binary, url, output, profile, environment, reference, timeout, identity):
    """Populate encoded responses, then discard the process and its decoded images."""
    warm_profile = output / 'vox-warm-profile'
    warm_profile.mkdir()
    shutil.copyfile(profile / 'settings.json', warm_profile / 'settings.json')
    audit = output / 'vox-warm.audit.json'
    requests = output / 'vox-warm.requests.jsonl'
    requests.touch()
    warm_environment = dict(environment, VOX_PROFILE_DIR=str(warm_profile),
                            VOX_CAPTURE_AUDIT_PATH=str(audit), VOX_ADBLOCK_LOG=str(requests))
    guarded([binary, '--window-width', '1024', '--window-height', '852',
             '--screenshot', output / 'vox-warm.png', url], output / 'vox-warm', timeout, warm_environment)
    if identity != executable_identity(binary):
        raise RuntimeError('Shared production bundle changed during cache warmup')
    check_native(read_json(audit), reference)


def guarded(command, prefix, timeout, environment=None):
    guard = [sys.executable, str(REPO / 'tools/run_memory_bounded.py'),
             '--limit-gib', '3', '--timeout', str(timeout), '--lock', str(prefix) + '.lock',
             '--report', str(prefix) + '.guard.json', '--', *map(str, command)]
    write_json(Path(str(prefix) + '.command.json'), guard)
    with Path(str(prefix) + '.log').open('w') as log:
        result = subprocess.run(guard, cwd=REPO, env=environment,
                                stdout=log, stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError(f'Command exited {result.returncode}; see {prefix}.log')
    return read_json(Path(str(prefix) + '.guard.json'))


def oracle_command(site, args):
    command = ['node', str(HARNESS), '--url', site['url'], '--extension', str(args.extension),
               '--checker', str(args.checker), '--brave', str(args.brave), '--settle', str(args.settle)]
    if args.profile_template:
        command.extend(['--profile-template', str(args.profile_template)])
    return command


def warm_oracle_cache(common, route, output, timeout, *, capture_archive=False):
    """Close the warmup browser before copying its encoded cache to a fresh one."""
    profile = output / 'brave-warm-profile'
    report = output / 'brave-warm.json'
    archive_options = ['--capture-dir', output / 'capture'] if capture_archive else []
    guarded([*common, *route, *archive_options, '--pixel-reference', output / 'brave-warm.png',
             '--output', report, '--profile-output', profile], output / 'brave-warm', timeout)
    check_filters(read_json(report))
    if not profile.is_dir():
        raise RuntimeError('Brave cache warmup did not save a closed profile')
    prepared = list(common)
    if '--profile-template' in prepared:
        prepared[prepared.index('--profile-template') + 1] = str(profile)
    else:
        prepared.extend(['--profile-template', str(profile)])
    if capture_archive:
        prepared.extend(['--cached-response-headers', str(output / 'capture')])
    return prepared


def capture_site_archive(common, route, output, archive, timeout, cache_policy):
    """Match the live oracle's encoded-cache policy to its frozen replay."""
    policy = output / 'capture-cache-policy.json'
    write_json(policy, dict(policy=cache_policy, warmup_qualified=False))
    prepared = common
    if cache_policy == 'complete':
        warmup = output / 'capture-warmup'
        warmup.mkdir()
        prepared = warm_oracle_cache(common, route, warmup, timeout, capture_archive=True)
        write_json(policy, dict(policy=cache_policy, warmup_qualified=True,
                               warmup_report=str(warmup / 'brave-warm.json'),
                               decoded_images='Fresh capture process; encoded cache retained'))
    capture = output / 'capture'
    report = output / 'capture.json'
    guarded([*prepared, *route, '--capture-dir', capture, '--output', report],
            output / 'capture', timeout)
    seal_capture(capture, archive, report)


def capture_replay_references(common, route, output, timeout, diff_tool):
    """Require two fresh processes to agree, including with a prepared cache.

    The oracle creates a new private profile/process per invocation. Both
    invocations copy the same closed cache template, if supplied; neither
    inherits decoded images or profile writes from the other. Keep every
    reference and full-uBO report, even when its pixels disagree.
    """
    for name in ['brave', 'brave-repeat']:
        report = output / (name + '.json')
        guarded([*common, '--pixel-reference', output / (name + '.png'),
                 '--output', report, *route], output / name, timeout)
        check_filters(read_json(report))
    verdict = compare(output / 'brave.png', output / 'brave-repeat.png',
                      output / 'reference-replay.diff.png', diff_tool)
    write_json(output / 'reference-replay.json', verdict)
    return verdict


def pixel_status(native, source, reference_repeat):
    # Reference variation invalidates acceptance even if the first reference
    # happens to match both the source and native captures exactly.
    if not reference_repeat['exact']:
        return 'reference-replay-mismatch'
    if not source['exact']:
        return 'live-to-frozen-mismatch'
    return 'pass' if native['exact'] else 'pixel-mismatch'


def run_case(site, args):
    output = args.output / site['id']
    output.mkdir(parents=True, exist_ok=False)
    before = dict(vox=executable_identity(args.vox), brave=brave_identity(args.brave))
    write_json(output / 'browser-identities.json', before)
    try:
        return capture_case(site, args, output)
    finally:
        after = dict(vox=executable_identity(args.vox), brave=brave_identity(args.brave))
        write_json(output / 'browser-identities-after.json', after)
        if before != after:
            raise RuntimeError('Browser inputs changed during the comparison')


def capture_case(site, args, output):
    archive = args.fixtures / site['id']
    common = oracle_command(site, args)
    if args.capture:
        capture_route = ['--proxy-server', args.capture_proxy] if args.capture_proxy else []
        capture_site_archive(common, capture_route, output, archive, args.timeout,
                             args.cache_policy)
    if not (archive / 'manifest.json').is_file() and (archive / 'status.json').is_file():
        unavailable = read_json(archive / 'status.json')
        raise RuntimeError('Site fixture unavailable: ' + unavailable['reason'])
    manifest = load_archive(archive)
    provenance = archive / 'capture.json'
    if digest(provenance.read_bytes()) != manifest['capture_report_sha256']:
        raise RuntimeError('Capture provenance changed')
    source_report = read_json(provenance)
    check_filters(source_report)
    current = read_json(REPO / 'adblock/lists/manifest.json')
    if (source_report['engine'] != current['engine']
            or source_report['lists'] != [{k: entry[k] for k in ['name', 'sha256']} for entry in current['lists']]):
        raise RuntimeError('Fixture uses different uBO engine or filter lists; capture a new fixture')
    replay = Replay(archive, output / 'replay')
    thread = threading.Thread(target=replay.server.serve_forever, daemon=True)
    thread.start()
    try:
        public = subprocess.check_output(['openssl', 'x509', '-in', replay.ready['ca'], '-pubkey', '-noout'])
        der = subprocess.check_output(['openssl', 'pkey', '-pubin', '-outform', 'DER'], input=public)
        spki = base64.b64encode(hashlib.sha256(der).digest()).decode()
        reference = output / 'brave.png'
        # Both browsers request the same original URLs from the same sealed proxy.
        common[common.index('--url') + 1] = manifest['url']
        cache_policy = getattr(args, 'cache_policy', 'cold')
        write_json(output / 'cache-policy.json', dict(policy=cache_policy, warmup_qualified=False))
        route = ['--proxy-server', replay.ready['proxy'].replace('socks5h:', 'socks5:'), '--replay-spki', spki]
        reference_command = warm_oracle_cache(common, route, output, args.timeout) if cache_policy == 'complete' else common
        repeat_verdict = capture_replay_references(reference_command, route, output,
                                                    args.timeout, args.diff_tool)
        state = read_json(Path(str(reference) + '.json'))
        if digest((archive / 'live.png').read_bytes()) != manifest['live_png_sha256']:
            raise RuntimeError('Live capture changed')
        replay_verdict = compare(archive / 'live.png', reference, output / 'live-to-frozen.diff.png', args.diff_tool)
        write_json(output / 'live-to-frozen.json', replay_verdict)
        profile = output / 'vox-profile'
        profile.mkdir()
        port = urlsplit(replay.ready['proxy']).port
        write_json(profile / 'settings.json', dict(enabled=True, host='127.0.0.1', port=str(port)))
        config = output / 'audit-config.json'
        write_json(config, read_json(args.audit_config) if args.audit_config else dict(selectors=[
            dict(name='body', selector='body', limit=1), dict(name='images', selector='img', limit=1000)]))
        requests = output / 'vox.requests.jsonl'
        requests.touch()
        audit = output / 'vox.audit.json'
        actual = output / 'vox.png'
        environment = native_capture_environment(profile, replay.ready['ca'], output / 'vox-cache',
            audit, config, requests, args.settle)
        before = executable_identity(args.vox)
        write_json(output / 'identity.json', before)
        if cache_policy == 'complete':
            warm_native_cache(args.vox, manifest['url'], output, profile, environment,
                              state, args.timeout, before)
            write_json(output / 'cache-policy.json', dict(policy=cache_policy, warmup_qualified=True,
                decoded_images='Fresh process; encoded response cache retained',
                oracle_warmup_report=str(output / 'brave-warm.json'),
                warmup_audit=str(output / 'vox-warm.audit.json')))
        guarded([args.vox, '--window-width', '1024', '--window-height', '852',
                 '--screenshot', actual, manifest['url']], output / 'vox', args.timeout, environment)
        if before != executable_identity(args.vox):
            raise RuntimeError('Shared production bundle changed during the capture')
        check_native(read_json(audit), state)
        guarded([*common, '--vox-log', requests, '--output', output / 'vox.ubo.json'],
                output / 'vox.ubo', args.timeout)
        check_filters(read_json(output / 'vox.ubo.json'), document=False)
        verdict = compare(reference, actual, output / 'diff.png', args.diff_tool)
        write_json(output / 'pixels.json', verdict)
        status = pixel_status(verdict, replay_verdict, repeat_verdict)
        return dict(status=status,
                    cache_policy=cache_policy,
                    different_pixels=verdict['different_pixels'], artifacts=str(output),
                    live_to_frozen_different_pixels=replay_verdict['different_pixels'],
                    reference_replay_different_pixels=repeat_verdict['different_pixels'],
                    manifest_sha256=digest((archive / 'manifest.json').read_bytes()))
    finally:
        replay.server.shutdown()
        replay.server.server_close()
        thread.join()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sites', help='Comma-separated catalog IDs; default: all registered sites sequentially')
    parser.add_argument('--capture', action='store_true', help='Capture new fixtures; never overwrite existing fixtures')
    parser.add_argument('--capture-proxy', help='Process-local Brave proxy for the initial live capture only')
    parser.add_argument('--fixtures', type=Path, default=REPO / 'Tests/Browser/Brave/sites')
    parser.add_argument('--output', type=Path, default=REPO / 'Build' / ('forum-news-pixels-' + time.strftime('%Y%m%d-%H%M%S')))
    parser.add_argument('--extension', type=Path, required=True, help='Full MV2 uBO matching adblock/lists/manifest.json')
    parser.add_argument('--checker', type=Path, required=True, help='Native tools/adblock_check.v executable')
    parser.add_argument('--brave', type=Path, default=BRAVE)
    parser.add_argument('--profile-template', type=Path,
                        help='Copy a closed prepared Brave profile into each disposable oracle profile')
    parser.add_argument('--vox', type=Path, default=VOX)
    parser.add_argument('--cache-policy', choices=['cold', 'complete'], default='cold',
                        help='Use an empty native cache, or warm live capture and both replay browsers in discarded processes first')
    parser.add_argument('--diff-tool', type=Path)
    parser.add_argument('--audit-config', type=Path, help='Native capture selectors for diagnosing a mismatch; include body and images')
    parser.add_argument('--settle', type=float, default=5)
    parser.add_argument('--timeout', type=float, default=180)
    args = parser.parse_args()
    if not 0 < args.settle <= 120 or not 0 < args.timeout <= 3600:
        parser.error('settle must be in (0,120], timeout in (0,3600]')
    sites = read_json(CATALOG)['sites']
    if args.sites:
        selected = args.sites.split(',')
        if len(selected) != len(set(selected)) or set(selected) - {s['id'] for s in sites}:
            parser.error('Unknown or duplicate site selection')
        sites = [next(s for s in sites if s['id'] == key) for key in selected]
    for name in ['fixtures', 'output', 'extension', 'checker', 'brave', 'vox']:
        setattr(args, name, getattr(args, name).resolve())
    if args.audit_config:
        args.audit_config = args.audit_config.resolve()
    if args.profile_template:
        args.profile_template = args.profile_template.resolve()
        if not args.profile_template.is_dir():
            parser.error('profile-template must be an existing closed Brave profile directory')
    args.output.mkdir(parents=True, exist_ok=False)
    if args.diff_tool:
        args.diff_tool = args.diff_tool.resolve()
    else:
        args.diff_tool = args.output / 'pixel_diff'
        compiler = os.environ.get('V_BIN') or shutil.which('v') or str(Path.home() / 'code/v/v')
        guarded([compiler, '-memory-limit', '10G', '-nocache', '-o', args.diff_tool, REPO / 'tools/pixel_diff.v'],
                args.output / 'diff-tool', args.timeout)
    summary = dict(started_at=time.strftime('%Y-%m-%dT%H:%M:%S%z'), catalog=str(CATALOG),
                   threshold='zero differing RGBA pixels', cache_policy=args.cache_policy, sites=[])
    for site in sites:
        print(f"[{site['id']}] {site['url']}", flush=True)
        try:
            result = run_case(site, args)
        except Exception as error:
            result = dict(status='failure', error=str(error))
        summary['sites'].append(dict(**site, **result))
        summary['passed'] = sum(s['status'] == 'pass' for s in summary['sites'])
        write_json(args.output / 'summary.json', summary)
        print(json.dumps(summary['sites'][-1], ensure_ascii=False), flush=True)
    return 0 if summary['passed'] == len(sites) else 1


if __name__ == '__main__':
    sys.exit(main())
