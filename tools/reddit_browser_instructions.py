#!/usr/bin/env python3
"""Compare retired instructions for identical frozen, pixel-exact Reddit captures.

Counts cover process launch through capture. Vox additionally includes teardown;
both observed process trees are polling lower bounds. Neither includes GPU
instructions or external services. Archived HTTP bodies feed both engines;
missing responses fail offline. This does not measure live JavaScript parity.
"""
from contextlib import contextmanager
import argparse
import hashlib
import json
import os
from pathlib import Path
import statistics
import sys
import tempfile
import time
from fractions import Fraction
from html.parser import HTMLParser
from types import SimpleNamespace

import measure_browser_instructions as measurement
from probe_frozen_github_chrome import ReplayCDP
from process_instruction_counts import MacCounters
from check_pixel_equality import compare

REPO = Path(__file__).resolve().parents[1]
IMAGE_ACCEPT = 'image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fingerprint_tree(directory):
    hashes = {str(p.relative_to(directory)): digest(p)
              for p in sorted(directory.rglob('*')) if p.is_file()}
    return hashlib.sha256(json.dumps(hashes, sort_keys=True).encode()).hexdigest()


def frozen_response(cache, url, resource_type):
    variants = [url + '\nAccept: ' + (IMAGE_ACCEPT if resource_type == 'Image' else '*/*'), url]
    for variant in variants:
        path = cache / 'resources' / hashlib.sha256(variant.encode()).hexdigest()
        header_path = path.with_name(path.name + '.headers.json')
        final_path = path.with_name(path.name + '.url')
        if not all(p.is_file() for p in [path, header_path, final_path]):
            continue
        if final_path.read_text() != url:
            continue
        status_path = path.with_name(path.name + '.status')
        if status_path.exists() and status_path.read_text().strip() != '200':
            continue
        body = path.read_bytes()
        if not body or len(body) > 16 * 1024 * 1024:
            continue
        headers = json.loads(header_path.read_text())
        mime = next((h['value'] for h in headers if h['name'].lower() == 'content-type'),
                    'application/octet-stream')
        return body, mime, path
    return None


class FrozenAssetsCDP(ReplayCDP):
    def __init__(self, url, cache):
        super().__init__(url, cache)
        self.call('Network.enable')
        self.call('Network.setCacheDisabled', {'cacheDisabled': True})
        self.call('Network.setBypassServiceWorker', {'bypass': True})
        self.call('Fetch.enable', {'patterns': [{'urlPattern': 'http*', 'requestStage': 'Request'}]})

    def lookup_response(self, url, resource_type):
        return frozen_response(self.cache, url, resource_type)

    def replay_headers(self, body, mime, path):
        headers = json.loads(path.with_name(path.name + '.headers.json').read_text())
        # Cache bodies are decoded; transport framing cannot be replayed literally.
        headers = [h for h in headers if h['name'].lower() not in
                   ['content-encoding', 'transfer-encoding', 'content-length']]
        return headers + [{'name': 'content-length', 'value': str(len(body))}]


class RedditAssetsCDP(FrozenAssetsCDP):
    def call(self, method, params=None):
        marker = "paint:performance.getEntriesByType('paint').map(r=>r.toJSON())"
        if method == 'Runtime.evaluate' and params and marker in params.get('expression', ''):
            params = dict(params)
            params['expression'] = params['expression'].replace(marker, marker +
                ',viewport_width:innerWidth,viewport_height:innerHeight,'
                'postIds:[...document.querySelectorAll(\'.thing[data-fullname^="t3_"]\')]'
                '.map(e=>e.getAttribute("data-fullname"))')
        return super().call(method, params)


def document_identity(path):
    class Identity(HTMLParser):
        in_title = False
        def handle_starttag(self, tag, attrs):
            attrs = dict(attrs)
            if tag == 'title':
                self.in_title = True
            if ('thing' in attrs.get('class', '').split()
                    and attrs.get('data-fullname', '').startswith('t3_')):
                posts.append(attrs['data-fullname'])
        def handle_endtag(self, tag):
            if tag == 'title':
                self.in_title = False
        def handle_data(self, value):
            if self.in_title:
                title.append(value)
    title, posts = [], []
    Identity().feed(path.read_text())
    title = ''.join(title).strip()
    if not title or not posts or len(posts) != len(set(posts)):
        raise ValueError('Frozen Reddit input must have a title and unique post identities')
    return title, posts


def vox_launch_arguments(js_engine):
    if js_engine not in ('javascriptcore', 'libjs'):
        raise ValueError('Vox supports javascriptcore or libjs, not V8')
    return ['--enable-javascript', '--js-engine='+js_engine]


def validate_document(report, url, title, posts, engine):
    audit = report['document_audit']
    if (audit.get('url') != url or audit.get('ready') != 'complete' or audit.get('title') != title
            or [audit.get('viewport_width'), audit.get('viewport_height')] != [1024, 768]):
        raise RuntimeError('Reddit document identity, readiness or viewport differs')
    if engine == 'vox':
        if not audit.get('fully_active') or audit.get('paint_commands', 0) <= 0:
            raise RuntimeError('Reddit document is inactive or unpainted')
        selection = next((s for s in audit.get('selections', []) if s.get('name') == 'posts'), {})
        actual = [row.get('attributes', {}).get('data-fullname')
                  for row in selection.get('elements', [])]
        if selection.get('count') != len(posts):
            raise RuntimeError('Reddit document omitted posts')
    else:
        actual = audit.get('postIds')
    if actual != posts:
        raise RuntimeError('Reddit document omitted or reordered posts')


@contextmanager
def native_environment(network_deny):
    keys = ['DYLD_INSERT_LIBRARIES', 'VOX_TEST_WINDOW', 'VOX_COOKIE_FILE',
            'LADYBIRD_ENABLE_SNAPSHOT_CACHE', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY',
            'http_proxy', 'https_proxy', 'all_proxy']
    saved = {k: os.environ.get(k) for k in keys}
    try:
        for key in keys:
            os.environ.pop(key, None)
        os.environ.update(DYLD_INSERT_LIBRARIES=str(network_deny), VOX_TEST_WINDOW='1', VOX_COOKIE_FILE='')
        yield
    finally:
        for key, value in saved.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


@contextmanager
def private_measurement_environment(network_deny=None, scratch_dir=None):
    """Keep saved Vox settings and ambient controls out of either engine's run."""
    saved = dict(os.environ)
    try:
        clean = {key: value for key, value in saved.items()
                 if 'proxy' not in key.lower()
                 and not key.startswith(('VOX_', 'LADYBIRD_', 'DYLD_', 'GC_', 'JSC_'))}
        with tempfile.TemporaryDirectory(prefix='reddit-instruction-profile-', dir=scratch_dir) as profile:
            clean.update(VOX_PROFILE_DIR=profile, VOX_TEST_WINDOW='1', VOX_COOKIE_FILE='',
                         LADYBIRD_SCREENSHOT_SCALE='1')
            if network_deny:
                clean['DYLD_INSERT_LIBRARIES'] = str(network_deny)
            os.environ.clear()
            os.environ.update(clean)
            yield Path(profile)
    finally:
        os.environ.clear()
        os.environ.update(saved)


def evaluate_pairs(pairs, required_reduction=.15):
    if not pairs or any(set(pair) != {'vox', 'brave'} for pair in pairs):
        raise ValueError('Every measured pair must include Vox and Brave')
    if any(row.get('pixels_exact') is not True for pair in pairs for row in pair.values()):
        raise ValueError('Every measured browser capture must pass exact pixel equality')
    if any(type(row.get('exit')) is not int or row['exit'] != 0
           or row.get('shutdown_forced', False) is not False or row.get('valid', True) is not True
           for pair in pairs for row in pair.values()):
        raise ValueError('Every measured browser must have a recorded successful exit')
    vox = [p['vox']['instructions'] for p in pairs]
    brave = [p['brave']['instructions'] for p in pairs]
    if any(type(value) is not int or value <= 0 for value in vox + brave):
        raise ValueError('Instruction counters must be positive')
    target = 1 - Fraction(str(required_reduction))
    if not 0 < target <= 1:
        raise ValueError('Required reduction must be in [0, 1)')
    ratios = [v / b for v, b in zip(vox, brave)]
    return dict(vox_median_instructions=statistics.median(vox),
                brave_median_observed_instructions=statistics.median(brave),
                median_paired_reduction=1 - statistics.median(ratios),
                worst_vox_over_best_brave=max(vox) / min(brave),
                required_reduction=required_reduction,
                passed=max(vox) * target.denominator <= target.numerator * min(brave))


def engine_reference(args, engine):
    """A Vox-specific reference checks per-engine stability, not cross-browser equality."""
    vox_reference = getattr(args, 'expected_vox', None)
    return vox_reference if engine == 'vox' and vox_reference is not None else args.expected


def pinned_inputs(args):
    from measure_sealed_github_instructions import native_dependencies
    paths = {args.html, args.expected, args.vox, args.brave, args.network_deny,
             getattr(args, 'diff_tool', REPO / 'Build/pixel-equality/pixel_diff'), *native_dependencies(args.vox),
             *args.vox.parent.glob('*.dylib')}
    if getattr(args, 'expected_vox', None) is not None:
        paths.add(args.expected_vox)
    for path in (args.vox.with_name('VoxAdblockWorker'),
                 args.vox.parent.parent / 'Resources/adblock.snapshot.bin'):
        if path.is_file():
            paths.add(path)
    frameworks = args.brave.parent.parent / 'Frameworks/Brave Browser Framework.framework/Versions'
    paths.update(path.resolve() for path in frameworks.glob('*/Brave Browser Framework'))
    paths.update(REPO / 'tools' / name for name in (
        'reddit_browser_instructions.py', 'measure_browser_instructions.py',
        'process_instruction_counts.py', 'probe_frozen_github_chrome.py',
        'check_pixel_equality.py', 'measure_sealed_github_instructions.py'))
    return {str(path.resolve()): digest(path) for path in paths}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--html', type=Path, required=True)
    parser.add_argument('--expected', type=Path, required=True)
    parser.add_argument('--expected-vox', type=Path,
                        help='Compare Vox captures with this fixed Vox reference instead of --expected. '
                             'Brave still uses --expected; the summary records the cross-browser difference.')
    parser.add_argument('--cache', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--vox', type=Path, default=REPO/'Build/v/Vox.app/Contents/MacOS/Vox')
    parser.add_argument('--brave', type=Path, default=Path('/Applications/Brave Browser.app/Contents/MacOS/Brave Browser'))
    parser.add_argument('--vox-js-engine', choices=['javascriptcore', 'libjs'], default='javascriptcore',
                        help='Explicit Vox backend selection; Brave uses V8. A script-free page may not create a runtime.')
    parser.add_argument('--network-deny', type=Path, default=REPO/'Build/pikabu-instructions-network-deny.dylib')
    parser.add_argument('--diff-tool', type=Path, default=REPO/'Build/pixel-equality/pixel_diff')
    parser.add_argument('--repeat', type=int, default=7)
    parser.add_argument('--required-reduction', type=float, default=.15)
    args = parser.parse_args()
    if args.repeat < 1 or not 0 <= args.required_reduction < 1:
        parser.error('Invalid repeat count or required reduction')
    for name in ['html', 'expected', 'expected_vox', 'cache', 'output', 'vox', 'brave', 'network_deny', 'diff_tool']:
        if getattr(args, name) is not None:
            setattr(args, name, getattr(args, name).resolve())
    if not args.network_deny.is_file():
        parser.error('Build the process-local network deny dylib first')
    args.output.mkdir(parents=True, exist_ok=False, mode=0o700)
    cross_browser = None
    if args.expected_vox is not None:
        cross_browser = compare(args.expected, args.expected_vox,
                                args.output/'vox-reference-vs-brave-reference.diff.png', args.diff_tool)
    title, posts = document_identity(args.html)
    audit_config = args.output/'post-audit-config.json'
    audit_config.write_text(json.dumps(dict(selectors=[dict(name='posts',
        selector='.thing[data-fullname^="t3_"]', limit=len(posts),
        attributes=['data-fullname'], layout_depth=0)])))
    pinned = pinned_inputs(args)
    cache_hash = fingerprint_tree(args.cache)
    api = MacCounters()
    pairs = []
    for index in range(args.repeat):
        pair = {}
        for engine in (['vox', 'brave'] if index % 2 == 0 else ['brave', 'vox']):
            prefix = args.output / f'pair-{index+1}.{engine}'
            config = SimpleNamespace(binary=args.vox if engine=='vox' else args.brave,
                url=args.html.as_uri(), width=1024, height=768, timeout=90,
                scratch_dir=args.output, sample_interval=.005,
                vox_arg=vox_launch_arguments(args.vox_js_engine), chrome_launch_mode='blank',
                chrome_disable_javascript=False,
                chrome_extra_arg=['--no-proxy-server', '--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE localhost'])
            started = time.time()
            host_before = dict(cpu_count=os.cpu_count(), load_average=os.getloadavg())
            with private_measurement_environment(args.network_deny if engine == 'vox' else None, args.output):
                if engine == 'vox':
                    os.environ['VOX_CAPTURE_AUDIT_PATH'] = str(prefix)+'.audit.json'
                    os.environ['VOX_CAPTURE_AUDIT_CONFIG'] = str(audit_config)
                    with measurement.fresh_vox_cache(args.cache, args.output) as (cache, _):
                        report = measurement.run_vox(config, prefix, api, cache)
                    report['document_audit'] = json.loads(Path(str(prefix)+'.audit.json').read_text())
                else:
                    report = measurement.run_chrome(config, prefix, api,
                        client_factory=lambda url: RedditAssetsCDP(url, args.cache))
            report.update(profile_policy='fresh empty private profile per observation', screenshot_scale=1,
                          selected_js_engine=args.vox_js_engine if engine == 'vox' else 'v8',
                          started_unix=started, finished_unix=time.time(), host_before=host_before,
                          host_after=dict(cpu_count=os.cpu_count(), load_average=os.getloadavg()))
            report_path = Path(str(prefix)+'.json')
            report_path.write_text(json.dumps(report, indent=2)+'\n')
            validate_document(report, config.url, title, posts, engine)
            report['content_exact'] = True
            verdict = compare(engine_reference(args, engine), Path(report['screenshot']),
                              Path(str(prefix)+'.diff.png'), args.diff_tool)
            report['pixels_exact'] = verdict['exact']
            report['pixel_comparison'] = verdict
            if report['unreadable_pids']:
                raise RuntimeError('Unreadable browser process counters')
            report_path.write_text(json.dumps(report, indent=2)+'\n')
            pair[engine] = report
            print(json.dumps(dict(pair=index+1,engine=engine,instructions=report['instructions'],
                                 pixels_exact=verdict['exact'])),flush=True)
            if not verdict['exact']:
                raise RuntimeError('Rendered viewport differs; this sample receives no performance credit')
            if pinned != pinned_inputs(args) or cache_hash != fingerprint_tree(args.cache):
                raise RuntimeError('Pinned runtime or benchmark input changed during measurement')
        pairs.append(pair)
    if pinned != pinned_inputs(args) or cache_hash != fingerprint_tree(args.cache):
        raise RuntimeError('Pinned executable, runtime or benchmark input changed')
    summary = evaluate_pairs(pairs, args.required_reduction)
    summary.update(reference_policy='per-engine fixed references' if cross_browser else 'shared Brave reference',
                   cross_browser_reference_pixels=cross_browser)
    summary.update(pairs=pairs, pinned_sha256=pinned, cache_sha256=cache_hash,
                   selected_js_engines=dict(vox=args.vox_js_engine, brave='v8'),
                   title=title, post_ids=posts, sample_interval_seconds=.005,
                   collector_environment={key: os.environ[key] for key in
                       ['GC_INITIAL_HEAP_SIZE','GC_MAXIMUM_HEAP_SIZE','GC_FREE_SPACE_DIVISOR','GC_MARKERS']
                       if key in os.environ},
                   counter='proc_pid_rusage/RUSAGE_INFO_V4/ri_instructions',
                   scope=__doc__, viewport=[1024,768], scripting_policy_enabled=True,
                   workload_note='Frozen input has executable script elements removed; preserve normal noscript semantics.')
    (args.output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps({k:v for k,v in summary.items() if k not in ['pairs','pinned_sha256','scope']}),flush=True)
    return 0 if summary['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
