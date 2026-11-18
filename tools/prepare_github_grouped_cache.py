#!/usr/bin/env python3
"""Seed, trace, pack, and reopen a private native cache on frozen GitHub."""

import argparse
from contextlib import nullcontext
import json
from pathlib import Path
import subprocess
import sys
from types import SimpleNamespace

import benchmark_github_page as benchmark
from browser_bundle_lease import canonical_bundle_lease
from libjs_pack_native_cache import pack_from_benchmark


BUNDLE = benchmark.ROOT / 'Build/v/Vox.app'
BINARY = BUNDLE / 'Contents/MacOS/Vox'
PRODUCTION = benchmark.ROOT / 'Build/production-build/latest.json'


def verify_inputs(pins):
    changed = [path for path, pin in pins.items()
               if not Path(path).is_file() or benchmark.digest(path) != pin]
    if changed:
        raise ValueError('Pinned workflow inputs changed: ' + ', '.join(changed))


def verify_reopen(separate, grouped, packed, output, diff_tool):
    if packed['library'] not in grouped['native_library_trace']['libraries']:
        raise ValueError('Grouped reopen did not load the packed library')
    expected = Path(separate['folder']) / 'document.png'
    actual = Path(grouped['folder']) / 'document.png'
    pixels = benchmark.compare(expected, actual, output / 'grouped-diff.png', diff_tool)
    if not pixels['exact']:
        raise ValueError('Grouped reopen differs from the separate-cache image')
    return pixels


def run(args):
    output, cache_work = args.output.resolve(), args.cache_work.resolve()
    if output.is_relative_to(cache_work) or cache_work.is_relative_to(output):
        raise ValueError('Use separate roots for reports and native cache work')
    if output.exists() or cache_work.exists():
        raise FileExistsError('The reports and native cache work directories must be new')
    output.mkdir(parents=True)
    cache_work.mkdir(parents=True, mode=0o700)
    separate, captures, grouped = (cache_work / name for name in ('separate', 'captures', 'grouped'))
    report_path = output / 'results.json'
    report = dict(complete=False, cache_work=str(cache_work), grouped_cache=str(grouped), stages={})
    stage = 'pin'

    def browser_visit(name, cache, *, prepare=False):
        folder = output / name
        options = SimpleNamespace(**(vars(args) | dict(
            output=folder, vox=BINARY, brave=Path('/Applications/Brave Browser.app/Contents/MacOS/Brave Browser'),
            engines=['libjs-native'], repeat=1, prepare_native_cache=prepare, native_cache=cache,
            native_captures=captures if prepare else None, native_compiler=benchmark.CAPTURE_COMPILER,
            native_diagnostics=False, trace_native_libraries=not prepare)))
        path = folder / 'results.json'
        report['stages'][name] = str(path)
        benchmark.save(report_path, report)
        status = benchmark.run(options, bundle_lease=lambda _: nullcontext())
        result = json.loads(path.read_text())
        if status or not result['complete']:
            error = result['attempts'][-1].get('error') if result['attempts'] else None
            raise ValueError(error or f'{name} did not complete')
        if result['production_receipt']['executable_sha256'] != report['production']['executable_sha256']:
            raise ValueError('Browser publication changed during ' + name)
        return result

    benchmark.save(report_path, report)
    try:
        with canonical_bundle_lease(BUNDLE):
            entry = json.loads(PRODUCTION.read_text())
            if entry['exit'] != 0 or benchmark.digest(BINARY) != entry['executable_sha256']:
                raise ValueError('The canonical Vox executable differs from its completed production receipt')
            report['production'] = entry
            stage = 'seed'
            seeded = browser_visit(stage, separate, prepare=True)
            pins = seeded['inputs']
            stage = 'trace'
            verify_inputs(pins)
            traced = browser_visit(stage, separate)

        stage = 'pack'
        verify_inputs(pins)
        packed = pack_from_benchmark(output / 'seed/results.json', output / 'trace/results.json', grouped)
        benchmark.save(output / 'pack.json', packed)
        report['stages']['pack'] = str(output / 'pack.json')
        image = grouped / packed['abi'] / packed['library']
        pins = pins | {str(image): packed['group_sha256']}
        benchmark.save(report_path, report)

        stage = 'reopen'
        with canonical_bundle_lease(BUNDLE):
            verify_inputs(pins)
            if benchmark.digest(BINARY) != entry['executable_sha256']:
                raise ValueError('The published Vox executable changed before the grouped reopen')
            reopened = browser_visit(stage, grouped)
            verify_inputs(pins)
        stage = 'compare'
        report['pixels'] = verify_reopen(traced['attempts'][0], reopened['attempts'][0],
                                         packed, output, args.diff_tool)
        report['complete'] = True
    except (OSError, KeyError, TypeError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        report['failure'] = dict(stage=stage, error=str(error))
        print(f'Grouped LibJS cache {stage}: {error}', file=sys.stderr)
    benchmark.save(report_path, report)
    return 0 if report['complete'] else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--reference-audit', type=Path, required=True)
    parser.add_argument('--reference-png', type=Path, required=True)
    parser.add_argument('--diff-tool', type=Path, default=benchmark.ROOT / 'Build/pixel-tools/pixel_diff')
    parser.add_argument('--output', type=Path, required=True, help='new directory for replay reports and captures')
    parser.add_argument('--cache-work', type=Path, required=True, help='new private directory for code and cache files')
    parser.add_argument('--memory-guard-registry', type=Path, required=True)
    parser.add_argument('--adblock-assets', type=Path)
    parser.add_argument('--raster-parity-options', action='store_true')
    parser.add_argument('--settle-seconds', type=float, default=1)
    parser.add_argument('--timeout', type=float, default=180, help='browser timeout per visit in seconds')
    args = parser.parse_args()
    if not 0 <= args.settle_seconds < args.timeout:
        parser.error('Require a settle period below the browser timeout')
    try:
        return run(args)
    except (OSError, ValueError) as error:
        print(f'Grouped LibJS cache: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
