#!/usr/bin/env python3
"""Seed, trace, pack, and reopen a private native cache on frozen GitHub."""

import argparse
from contextlib import nullcontext
import fcntl
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


def verify_compatible_publication(earlier, published):
    if earlier['executable_sha256'] == published['executable_sha256']:
        return
    source_sets = []
    for receipt in (earlier, published):
        path = Path(receipt['frozen_compilation']).with_name('source-manifest.json')
        manifest = json.loads(path.read_text())
        source_sets.append({name: sha for name, sha in manifest.items()
                            if Path(name).is_relative_to(benchmark.ROOT / 'libjs')})
    if not source_sets[0] or source_sets[0] != source_sets[1] or earlier['c_compile'] != published['c_compile']:
        raise ValueError('The current publication has different LibJS or compiler inputs')


def replay_pins(args, receipt, options):
    assets = args.adblock_assets.resolve() if args.adblock_assets else None
    parity = all(options.get('VOX_DIAGNOSTIC_' + name) == '1' for name in benchmark.RASTER_OPTIONS)
    if options.get('VOX_ADBLOCK_ENGINE_ASSETS') != (str(assets) if assets else None) or parity != args.raster_parity_options:
        raise ValueError('The saved replay settings differ')
    pins = {str(Path(path).resolve()): sha for path, sha in receipt['inputs'].items()}
    required = {str(path.resolve()) for path in (args.archive / 'manifest.json', args.reference_audit, args.reference_png)}
    if required - pins.keys():
        raise ValueError('The saved replay inputs differ')
    return {path: sha for path, sha in pins.items() if path in required
            or (assets and Path(path).is_relative_to(assets))}


def verify_interrupted_seed(args, checkpoint, cache_work, published):
    previous = json.loads(checkpoint.read_text())
    if (previous['complete'] or set(previous['stages']) != {'seed'}
            or Path(previous['cache_work']).resolve() != cache_work):
        raise ValueError('Expected an interrupted seed for this native cache work directory')
    earlier = previous['production']
    directory = checkpoint.parent / 'seed'
    seeded = json.loads((directory / 'results.json').read_text())
    options = json.loads((directory / '0-libjs-native/launch.json').read_text())['browser_overrides']
    captures, separate = cache_work / 'captures', cache_work / 'separate'
    if (not seeded['prepare_native_cache'] or seeded.get('complete')
            or Path(seeded['native_captures']).resolve() != captures
            or Path(options['VOX_LIBJS_NATIVE_CACHE']).resolve() != separate):
        raise ValueError('Interrupted seed and resumed cache settings differ')
    replay_pins(args, seeded, options)
    pins = {str(Path(path).resolve()): sha for path, sha in seeded['inputs'].items()}
    # The resume feature can update the driver. The renderer, compiler, replay,
    # and fixture inputs retain the exact byte identities from the old attempt.
    driver = str(Path(benchmark.__file__).resolve())
    prior_driver = pins.pop(driver)
    if earlier['executable_sha256'] != published['executable_sha256']:
        verify_compatible_publication(earlier, published)
        pins.pop(str(BINARY.resolve()))
    verify_inputs(pins)
    abis = [path.name for path in separate.iterdir() if path.is_dir() and benchmark.SHA256.fullmatch(path.name)]
    if len(abis) != 1:
        raise ValueError('Expected one captured native cache ABI in the interrupted seed')
    saved = benchmark.verify_compiler_captures(captures, separate, abis[0])
    return dict(path=str(checkpoint.resolve()), sha256=benchmark.digest(checkpoint), abi=saved['abi'],
                records=saved['records'], batches=len(saved['batches']),
                previous_executable_sha256=earlier['executable_sha256'],
                previous_driver_sha256=prior_driver, driver_sha256=benchmark.digest(driver))


def verify_packed_checkpoint(args, checkpoint, cache_work, published):
    previous = json.loads(checkpoint.read_text())
    separate, grouped = cache_work / 'separate', cache_work / 'grouped'
    if ('pack' not in previous['stages'] or Path(previous['cache_work']).resolve() != cache_work
            or Path(previous['grouped_cache']).resolve() != grouped):
        raise ValueError('Expected completed packing for this native cache work directory')
    verify_compatible_publication(previous['production'], published)
    packed = json.loads((checkpoint.parent / 'pack.json').read_text())
    trace_pin = packed['benchmark']['trace']
    trace_path = Path(trace_pin['path'])
    if not trace_path.is_file():
        trace_path = checkpoint.parent / 'trace/results.json'
    verify_inputs({str(trace_path): trace_pin['sha256']})
    trace = json.loads(trace_path.read_text())
    row, = trace['attempts']
    options = row['browser_overrides']
    if not trace['complete'] or not row['valid'] or Path(options['VOX_LIBJS_NATIVE_CACHE']).resolve() != separate:
        raise ValueError('Packed cache and saved trace differ')
    verify_inputs(replay_pins(args, trace, options))
    pins = {name: sha for name, sha in trace['inputs'].items() if Path(name).is_relative_to(separate)}
    if not pins or set(pins) != {str(path) for path in separate.rglob('*') if path.is_file()}:
        raise ValueError('The traced separate-cache file set changed')
    image = grouped / packed['abi'] / packed['library']
    verify_inputs(pins | {str(image): packed['group_sha256']})
    return packed


def run(args):
    output, cache_work = args.output.resolve(), args.cache_work.resolve()
    checkpoint = getattr(args, 'resume_seed', None)
    packed_checkpoint = getattr(args, 'verify_packed', None)
    if output.is_relative_to(cache_work) or cache_work.is_relative_to(output):
        raise ValueError('Use separate roots for reports and native cache work')
    if output.exists():
        raise FileExistsError('The reports directory must be new')
    if checkpoint is None and packed_checkpoint is None:
        cache_work.mkdir(parents=True, mode=0o700)
    elif not cache_work.is_dir():
        raise ValueError('Continuing requires the original cache work directory')
    with (cache_work / '.workflow.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        output.mkdir(parents=True)
        return run_workflow(args, output, cache_work, checkpoint, packed_checkpoint)


def run_workflow(args, output, cache_work, checkpoint, packed_checkpoint):
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
        saved = report.get('resume_seed')
        status = benchmark.run(options, bundle_lease=lambda _: nullcontext(),
                               resume_native_abi=saved['abi'] if prepare and saved else None)
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
            if packed_checkpoint is not None:
                stage = 'verify-pack'
                packed = verify_packed_checkpoint(args, packed_checkpoint, cache_work, entry)
                report['verified_pack_from'] = str(packed_checkpoint.resolve())
                benchmark.save(output / 'pack.json', packed)
                report['stages']['pack'] = str(output / 'pack.json')
            else:
                if checkpoint is not None:
                    stage = 'resume'
                    report['resume_seed'] = verify_interrupted_seed(args, checkpoint, cache_work, entry)
                stage = 'seed'
                seeded = browser_visit(stage, separate, prepare=True)
                verify_inputs(seeded['inputs'])
            stage = 'trace'
            traced = browser_visit(stage, separate)
            if packed_checkpoint is not None:
                image = grouped / packed['abi'] / packed['library']
                pins = traced['inputs'] | {str(image): packed['group_sha256']}
                stage = 'reopen'
                verify_inputs(pins)
                reopened = browser_visit(stage, grouped)
                verify_inputs(pins)

        if packed_checkpoint is None:
            stage = 'pack'
            pins = seeded['inputs']
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
    parser.add_argument('--cache-work', type=Path, required=True, help='private directory for code and cache files')
    checkpoint = parser.add_mutually_exclusive_group()
    checkpoint.add_argument('--resume-seed', type=Path, help='results.json from an interrupted seed in --cache-work')
    checkpoint.add_argument('--verify-packed', type=Path, help='results.json from completed packing in --cache-work')
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
