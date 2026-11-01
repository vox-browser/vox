#!/usr/bin/env python3
"""Compare retired instructions for identical frozen, pixel-exact Reddit captures.

Counts cover process launch through capture. Vox additionally includes teardown;
Brave's observed process tree is a polling lower bound. Neither includes GPU
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
from fractions import Fraction
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


def pinned_inputs(args):
    from measure_sealed_github_instructions import native_dependencies
    paths = {args.html, args.expected, args.vox, args.brave, args.network_deny,
             REPO / 'Build/pixel-equality/pixel_diff', *native_dependencies(args.vox),
             *args.vox.parent.glob('*.dylib')}
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
    parser.add_argument('--cache', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--vox', type=Path, default=REPO/'Build/v/Vox.app/Contents/MacOS/Vox')
    parser.add_argument('--brave', type=Path, default=Path('/Applications/Brave Browser.app/Contents/MacOS/Brave Browser'))
    parser.add_argument('--network-deny', type=Path, default=REPO/'Build/pikabu-instructions-network-deny.dylib')
    parser.add_argument('--repeat', type=int, default=7)
    parser.add_argument('--required-reduction', type=float, default=.15)
    args = parser.parse_args()
    if args.repeat < 1 or not 0 <= args.required_reduction < 1:
        parser.error('Invalid repeat count or required reduction')
    for name in ['html', 'expected', 'cache', 'output', 'vox', 'brave', 'network_deny']:
        setattr(args, name, getattr(args, name).resolve())
    if not args.network_deny.is_file():
        parser.error('Build the process-local network deny dylib first')
    args.output.mkdir(parents=True, exist_ok=False, mode=0o700)
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
                vox_arg=['--enable-javascript'], chrome_launch_mode='blank',
                chrome_disable_javascript=False,
                chrome_extra_arg=['--no-proxy-server', '--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE localhost'])
            with private_measurement_environment(args.network_deny if engine == 'vox' else None, args.output):
                if engine == 'vox':
                    with measurement.fresh_vox_cache(args.cache, args.output) as (cache, _):
                        report = measurement.run_vox(config, prefix, api, cache)
                else:
                    report = measurement.run_chrome(config, prefix, api,
                        client_factory=lambda url: FrozenAssetsCDP(url, args.cache))
            report.update(profile_policy='fresh empty private profile per observation', screenshot_scale=1)
            report_path = Path(str(prefix)+'.json')
            report_path.write_text(json.dumps(report, indent=2)+'\n')
            verdict = compare(args.expected, Path(report['screenshot']),
                              Path(str(prefix)+'.diff.png'), REPO/'Build/pixel-equality/pixel_diff')
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
    summary.update(pairs=pairs, pinned_sha256=pinned, cache_sha256=cache_hash,
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
