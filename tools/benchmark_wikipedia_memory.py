#!/usr/bin/env python3
"""Compare two windowed Vox bundles against the frozen Wikipedia portal.

Uses the strict document/resource audit and process-tree observer. The limit is
decimal MB of settled physical footprint before screenshot allocation; startup
peaks are reported independently. No collector overrides or diagnostic hooks.
"""
import argparse
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess

import wikipedia_browser_memory as observer


def summarize(rows, limit_bytes):
    before = [row for row in rows if row['variant'] == 'before']
    after = [row for row in rows if row['variant'] == 'after']
    if not before or len(before) != len(after):
        raise ValueError('Require the same positive number of before and after samples')
    if len({row['cache_digest'] for row in rows}) != 1:
        raise ValueError('Samples used different frozen caches')
    for variant in (before, after):
        if len({row['raw_viewport_sha256'] for row in variant}) != 1:
            raise ValueError('Document captures changed within a variant')
    exact = before[0]['raw_viewport_sha256'] == after[0]['raw_viewport_sha256']
    result = dict(limit_bytes=limit_bytes, capture_bytes_identical=exact)
    for name, group in [('before', before), ('after', after)]:
        values = [r['memory']['settled_physical_footprint_bytes'] for r in group]
        result[name] = dict(settled_bytes=values,
            median_settled_bytes=statistics.median(values),
            maximum_settled_bytes=max(values),
            maximum_settled_observation_bytes=max(r['memory']['settled_range_bytes'][1] for r in group),
            observed_launch_peak_bytes=[r['memory']['observed_simultaneous_peak_bytes'] for r in group])
    result['reduction_percent'] = 100 * (1 - result['after']['median_settled_bytes']
        / result['before']['median_settled_bytes'])
    result['passed'] = exact and result['after']['maximum_settled_observation_bytes'] <= limit_bytes
    return result


def bundle_files(binary):
    if binary.parent.name != 'MacOS' or binary.parent.parent.name != 'Contents':
        raise ValueError('Use a preserved .app/Contents/MacOS/Vox executable')
    return [p for p in binary.parents[2].rglob('*') if p.is_file()]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before', type=Path, required=True)
    parser.add_argument('--after', type=Path, required=True)
    parser.add_argument('--cache', type=Path, required=True)
    parser.add_argument('--network-deny', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--repeat', type=int, default=3)
    parser.add_argument('--limit-mb', type=float, default=100)
    parser.add_argument('--activity', choices=['foreground', 'background'], default='foreground')
    args = parser.parse_args()
    if args.repeat < 1 or args.limit_mb <= 0:
        parser.error('Require a positive repeat count and memory limit')
    for name in ('before', 'after', 'cache', 'network_deny', 'output'):
        setattr(args, name, getattr(args, name).resolve())
    args.settle, args.interval, args.timeout = 15, .005, 180
    args.foreground = args.activity == 'foreground'
    args.background = args.activity == 'background'
    args.diagnostic_gc_stats = args.diagnostic_vmmap = False
    args.background_anchor_pid = int(subprocess.check_output(['osascript', '-l', 'JavaScript', '-e',
        'ObjC.import("AppKit"); String(Number($.NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier))'],
        text=True)) if args.background else None
    args.output.mkdir(parents=True, exist_ok=False)
    files = [*bundle_files(args.before), *bundle_files(args.after), args.network_deny,
        Path(__file__), Path(observer.__file__), *(Path(__file__).parent / name for name in (
            'compare_browser_memory.py', 'measure_browser_instructions.py',
            'measure_browser_render.py', 'probe_frozen_github_chrome.py',
            'process_instruction_counts.py'))]
    pins = {str(p): observer.digest(p) for p in files}
    cache_pins = observer.fingerprint_tree(args.cache)
    screen = observer.placement()
    protocol = dict(url=observer.URL, viewport=[1024, 768], screen=screen,
        activity=args.activity, settle_seconds=args.settle, interval_seconds=args.interval,
        repeat=args.repeat, author_javascript=False, machine=platform.platform(),
        inherited_malloc_space_efficient=os.environ.get('MallocSpaceEfficient'),
        metric='Simultaneous sum of browser and descendant task physical footprints; decimal MB.',
        endpoint='Last second of 15s after readiness, before screenshot allocation.',
        peak='Observed simultaneous launch-to-endpoint peak, a polling lower bound.',
        limit_scope='Every observation in every after settled window; startup peak reported separately.',
        files_sha256=pins, cache_files_sha256=cache_pins)
    (args.output / 'protocol.json').write_text(json.dumps(protocol, indent=2) + '\n')
    rows = []
    for pair in range(1, args.repeat + 1):
        for variant in (['before', 'after'] if pair % 2 else ['after', 'before']):
            args.vox = getattr(args, variant)
            prefix = args.output / f'{pair}-{variant}'
            row = observer.vox_sample(args, prefix, screen)
            row.update(variant=variant, pair=pair)
            prefix.with_suffix('.json').write_text(json.dumps(row, indent=2) + '\n')
            rows.append(row)
            print(json.dumps(dict(pair=pair, variant=variant, memory=row['memory'])), flush=True)
    unchanged = all(observer.digest(Path(p)) == digest for p, digest in pins.items())
    unchanged = unchanged and observer.fingerprint_tree(args.cache) == cache_pins
    result = summarize(rows, int(args.limit_mb * 1_000_000))
    result['inputs_unchanged'] = unchanged
    result['passed'] = result['passed'] and unchanged
    (args.output / 'summary.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
