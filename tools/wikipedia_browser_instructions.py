#!/usr/bin/env python3
"""Compare retired instructions for identical frozen, pixel-exact Wikipedia captures.

Both engines render https://www.wikipedia.org/ from the same frozen cache
without page JavaScript: Vox through its HTML+CSS-only site policy, Brave with
author JavaScript disabled over CDP. Counts cover process launch through
capture. Vox additionally includes teardown; Brave's observed process tree is a
polling lower bound. Neither includes GPU instructions or external services.
Missing responses fail offline.
"""
import argparse
import json
import os
from pathlib import Path
import sys
from types import SimpleNamespace

import measure_browser_instructions as measurement
from process_instruction_counts import MacCounters
from check_pixel_equality import compare
from reddit_browser_instructions import (FrozenAssetsCDP, digest, evaluate_pairs,
    fingerprint_tree, native_environment)

REPO = Path(__file__).resolve().parents[1]
URL = 'https://www.wikipedia.org/'


def engine_config(args, engine):
    return SimpleNamespace(binary=args.vox if engine == 'vox' else args.brave,
        url=args.url, width=1024, height=768, timeout=90, scratch_dir=args.output,
        sample_interval=.005, vox_arg=[], chrome_launch_mode='blank',
        chrome_disable_javascript=True,
        chrome_extra_arg=['--no-proxy-server', '--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE localhost'])


def run_engine(args, engine, prefix, api):
    config = engine_config(args, engine)
    if engine == 'vox':
        with native_environment(args.network_deny), measurement.fresh_vox_cache(args.cache, args.output) as (cache, _):
            return measurement.run_vox(config, prefix, api, cache)
    return measurement.run_chrome(config, prefix, api,
        client_factory=lambda url: FrozenAssetsCDP(url, args.cache))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--expected', type=Path,
        help='Brave no-JavaScript reference; required unless --capture-reference')
    parser.add_argument('--capture-reference', action='store_true',
        help='Capture one Brave no-JavaScript reference into the output directory')
    parser.add_argument('--url', default=URL)
    parser.add_argument('--vox', type=Path, default=REPO/'Build/v/Vox.app/Contents/MacOS/Vox')
    parser.add_argument('--brave', type=Path, default=Path('/Applications/Brave Browser.app/Contents/MacOS/Brave Browser'))
    parser.add_argument('--network-deny', type=Path, default=REPO/'Build/pikabu-instructions-network-deny.dylib')
    parser.add_argument('--repeat', type=int, default=7)
    parser.add_argument('--required-reduction', type=float, default=.20)
    args = parser.parse_args()
    if args.repeat < 1 or not 0 <= args.required_reduction < 1:
        parser.error('Invalid repeat count or required reduction')
    if not args.capture_reference and args.expected is None:
        parser.error('--expected is required unless --capture-reference is given')
    for name in ['cache', 'output', 'vox', 'brave', 'network_deny']:
        setattr(args, name, getattr(args, name).resolve())
    if args.expected:
        args.expected = args.expected.resolve()
    if not args.network_deny.is_file():
        parser.error('Build the process-local network deny dylib first')
    args.output.mkdir(parents=True, exist_ok=False, mode=0o700)
    api = MacCounters()
    if args.capture_reference:
        report = run_engine(args, 'brave', args.output / 'brave-reference', api)
        print(json.dumps(dict(reference=report['screenshot'], instructions=report['instructions'])))
        return 0
    pinned = {str(p): digest(p) for p in [args.expected, args.vox, args.brave,
              args.network_deny, *sorted(args.vox.parent.glob('*.dylib'))]}
    cache_hash = fingerprint_tree(args.cache)
    pairs = []
    for index in range(args.repeat):
        pair = {}
        for engine in (['vox', 'brave'] if index % 2 == 0 else ['brave', 'vox']):
            prefix = args.output / f'pair-{index+1}.{engine}'
            report = run_engine(args, engine, prefix, api)
            verdict = compare(args.expected, Path(report['screenshot']),
                              Path(str(prefix)+'.diff.png'), REPO/'Build/pixel-equality/pixel_diff')
            report['pixels_exact'] = verdict['exact']
            report['pixel_comparison'] = verdict
            if report['unreadable_pids']:
                raise RuntimeError('Unreadable browser process counters')
            Path(str(prefix)+'.json').write_text(json.dumps(report, indent=2)+'\n')
            pair[engine] = report
            print(json.dumps(dict(pair=index+1, engine=engine, instructions=report['instructions'],
                                  pixels_exact=verdict['exact'])), flush=True)
            if not verdict['exact']:
                raise RuntimeError('Rendered viewport differs; this sample receives no performance credit')
        pairs.append(pair)
    if pinned != {name: digest(Path(name)) for name in pinned} or cache_hash != fingerprint_tree(args.cache):
        raise RuntimeError('Pinned executable, runtime or benchmark input changed')
    summary = evaluate_pairs(pairs, args.required_reduction)
    summary.update(pairs=pairs, pinned_sha256=pinned, cache_sha256=cache_hash,
                   collector_environment={key: os.environ[key] for key in
                       ['GC_INITIAL_HEAP_SIZE', 'GC_MAXIMUM_HEAP_SIZE', 'GC_FREE_SPACE_DIVISOR', 'GC_MARKERS']
                       if key in os.environ},
                   counter='proc_pid_rusage/RUSAGE_INFO_V4/ri_instructions',
                   scope=__doc__, viewport=[1024, 768], url=args.url, page_javascript=False)
    (args.output/'summary.json').write_text(json.dumps(summary, indent=2)+'\n')
    print(json.dumps({k: v for k, v in summary.items() if k not in ['pairs', 'pinned_sha256', 'scope']}), flush=True)
    return 0 if summary['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
