#!/usr/bin/env python3
"""Seed, trace, pack, and reopen a private native cache on frozen GitHub."""

import argparse
from contextlib import nullcontext
import fcntl
import json
from pathlib import Path
import shutil
import subprocess
import sys
from types import SimpleNamespace

import benchmark_github_page as benchmark
from browser_bundle_lease import canonical_bundle_lease
from libjs_pack_native_cache import benchmark_results, pack_from_benchmark


BUNDLE = benchmark.ROOT / 'Build/v/Vox.app'
BINARY = BUNDLE / 'Contents/MacOS/Vox'
PRODUCTION = benchmark.ROOT / 'Build/production-build/latest.json'


def verify_inputs(pins):
    changed = [path for path, pin in pins.items()
               if not Path(path).is_file() or benchmark.digest(path) != pin]
    if changed:
        raise ValueError('Pinned workflow inputs changed: ' + ', '.join(changed))


def save_workflow_receipt(path, value):
    temporary = path.with_suffix('.json.tmp')
    benchmark.save(temporary, value)
    temporary.replace(path)


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


def verify_trace_pins(args, trace, separate):
    row, = trace['attempts']
    options = row['browser_overrides']
    if not trace['complete'] or not row['valid'] or Path(options['VOX_LIBJS_NATIVE_CACHE']).resolve() != separate:
        raise ValueError('Saved trace does not match the separate cache')
    pins = {name: sha for name, sha in trace['inputs'].items() if Path(name).is_relative_to(separate)}
    if not pins or set(pins) != {str(path) for path in separate.rglob('*') if path.is_file()}:
        raise ValueError('The traced separate-cache file set changed')
    verify_inputs(pins | replay_pins(args, trace, options))


def verify_interrupted_pack(args, checkpoint, cache_work, published):
    previous = json.loads(checkpoint.read_text())
    if (previous['complete'] or set(previous['stages']) != {'seed', 'trace'}
            or Path(previous['cache_work']).resolve() != cache_work
            or Path(previous['grouped_cache']).resolve() != cache_work / 'grouped'):
        raise ValueError('Expected completed seed and trace stages for this unpublished group')
    if (cache_work / 'grouped').exists():
        raise ValueError('The grouped cache already exists in this cache work directory')

    def saved_report(name):
        path = checkpoint.parent / name / 'results.json'
        report, pin = benchmark_results(path if path.is_file() else Path(previous['stages'][name]))
        earlier_pin = previous.get('resume_pack', {}).get(name)
        if earlier_pin and pin['sha256'] != earlier_pin['sha256']:
            raise ValueError(f'The saved {name} report changed')
        return report, pin

    seed, seed_pin = saved_report('seed')
    trace, trace_pin = saved_report('trace')
    previous_publication = seed['production_receipt']
    if previous_publication['executable_sha256'] != trace['production_receipt']['executable_sha256']:
        raise ValueError('The saved seed and trace use different browser publications')
    verify_compatible_publication(previous_publication, published)
    seed_row, = seed['attempts']
    if (not seed['prepare_native_cache'] or not trace['trace_native_libraries']
            or Path(seed_row['compiler_captures']['directory']).resolve() != cache_work / 'captures'):
        raise ValueError('Expected a captured seed and loader trace for this cache work directory')
    verify_trace_pins(args, trace, cache_work / 'separate')
    stored_objects = previous.get('object_checkpoint')
    requested = args.object_checkpoint.resolve() if args.object_checkpoint else None
    if stored_objects and requested and Path(stored_objects).resolve() != requested:
        raise ValueError('The resumed object checkpoint directory differs')
    return dict(path=str(checkpoint.resolve()), sha256=benchmark.digest(checkpoint), seed=seed_pin, trace=trace_pin,
                object_checkpoint=(str(requested) if requested else stored_objects), production=previous_publication)


def retain_pack_inputs(saved, output):
    stages = {}
    for name in ('seed', 'trace'):
        source = Path(saved[name]['path'])
        target = output / name / 'results.json'
        target.parent.mkdir()
        shutil.copyfile(source, target)
        stages[name] = str(target)
    trace, _ = benchmark_results(Path(stages['trace']))
    row, = trace['attempts']
    folder = Path(row['folder']).name
    if folder in ('', '.', '..'):
        raise ValueError('Invalid saved loader trace folder')
    relative = Path(folder) / 'native-library-trace.log'
    source = Path(saved['trace']['path']).parent / relative
    target = output / 'trace' / relative
    target.parent.mkdir()
    shutil.copyfile(source, target)
    return stages


def verify_packed_checkpoint(args, checkpoint, cache_work, published):
    previous = json.loads(checkpoint.read_text())
    separate, grouped = cache_work / 'separate', cache_work / 'grouped'
    receipt = checkpoint.parent / 'pack.json'
    if (not receipt.is_file() or Path(previous['cache_work']).resolve() != cache_work
            or Path(previous['grouped_cache']).resolve() != grouped):
        raise ValueError('Expected completed packing for this native cache work directory')
    verify_compatible_publication(previous['production'], published)
    packed = json.loads(receipt.read_text())
    trace_pin = packed['benchmark']['trace']
    trace_path = Path(trace_pin['path'])
    if not trace_path.is_file():
        trace_path = checkpoint.parent / 'trace/results.json'
    verify_inputs({str(trace_path): trace_pin['sha256']})
    trace = json.loads(trace_path.read_text())
    verify_trace_pins(args, trace, separate)
    image = grouped / packed['abi'] / packed['library']
    verify_inputs({str(image): packed['group_sha256']})
    return packed


def run(args):
    output, cache_work = args.output.resolve(), args.cache_work.resolve()
    checkpoint = getattr(args, 'resume_seed', None)
    interrupted_pack = getattr(args, 'resume_pack', None)
    packed_checkpoint = getattr(args, 'verify_packed', None)
    if output.is_relative_to(cache_work) or cache_work.is_relative_to(output):
        raise ValueError('Use separate roots for reports and native cache work')
    if output.exists():
        raise FileExistsError('The reports directory must be new')
    if checkpoint is None and interrupted_pack is None and packed_checkpoint is None:
        cache_work.mkdir(parents=True, mode=0o700)
    elif not cache_work.is_dir():
        raise ValueError('Continuing requires the original cache work directory')
    with (cache_work / '.workflow.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        output.mkdir(parents=True)
        return run_workflow(args, output, cache_work, checkpoint, interrupted_pack, packed_checkpoint)


def run_workflow(args, output, cache_work, checkpoint, interrupted_pack, packed_checkpoint):
    separate, captures, grouped = (cache_work / name for name in ('separate', 'captures', 'grouped'))
    report_path = output / 'results.json'
    report = dict(complete=False, cache_work=str(cache_work), grouped_cache=str(grouped), stages={})
    if args.object_checkpoint:
        report['object_checkpoint'] = str(args.object_checkpoint.resolve())
    stage = 'pin'

    def publication():
        entry = json.loads(PRODUCTION.read_text())
        if entry['exit'] != 0 or benchmark.digest(BINARY) != entry['executable_sha256']:
            raise ValueError('The canonical Vox executable differs from its completed production receipt')
        report['production'] = entry
        return entry

    def record_pack(packed):
        save_workflow_receipt(output / 'pack.json', packed)
        report['stages']['pack'] = str(output / 'pack.json')
        save_workflow_receipt(report_path, report)

    def image_pin(packed):
        return {str(grouped / packed['abi'] / packed['library']): packed['group_sha256']}

    def browser_visit(name, cache, *, prepare=False):
        folder = output / name
        options = SimpleNamespace(**(vars(args) | dict(
            output=folder, vox=BINARY, brave=Path('/Applications/Brave Browser.app/Contents/MacOS/Brave Browser'),
            engines=['libjs-native'], repeat=1, prepare_native_cache=prepare, native_cache=cache,
            native_captures=captures if prepare else None, native_compiler=benchmark.CAPTURE_COMPILER,
            native_diagnostics=False, trace_native_libraries=not prepare)))
        path = folder / 'results.json'
        report['stages'][name] = str(path)
        save_workflow_receipt(report_path, report)
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

    def verify_pair(packed, control_stage):
        nonlocal stage
        stage = control_stage
        traced = browser_visit(stage, separate)
        pins = traced['inputs'] | image_pin(packed)
        stage = 'reopen'
        verify_inputs(pins)
        reopened = browser_visit(stage, grouped)
        verify_inputs(pins)
        return traced, reopened

    save_workflow_receipt(report_path, report)
    try:
        with canonical_bundle_lease(BUNDLE):
            entry = publication()
            if packed_checkpoint is not None:
                stage = 'verify-pack'
                packed = verify_packed_checkpoint(args, packed_checkpoint, cache_work, entry)
                report['verified_pack_from'] = str(packed_checkpoint.resolve())
                record_pack(packed)
                traced, reopened = verify_pair(packed, 'trace')
            elif interrupted_pack is not None:
                stage = 'resume-pack'
                saved = verify_interrupted_pack(args, interrupted_pack, cache_work, entry)
                report['resume_pack'] = saved
                if saved['object_checkpoint']:
                    report['object_checkpoint'] = saved['object_checkpoint']
                report['stages'].update(retain_pack_inputs(saved, output))
                save_workflow_receipt(report_path, report)
            else:
                if checkpoint is not None:
                    stage = 'resume'
                    report['resume_seed'] = verify_interrupted_seed(args, checkpoint, cache_work, entry)
                stage = 'seed'
                seeded = browser_visit(stage, separate, prepare=True)
                verify_inputs(seeded['inputs'])
                stage = 'trace'
                traced = browser_visit(stage, separate)

        if packed_checkpoint is None:
            stage = 'pack'
            if interrupted_pack is not None:
                verify_inputs({report['stages'][name]: saved[name]['sha256'] for name in ('seed', 'trace')})
            else:
                verify_inputs(seeded['inputs'])
            objects = report.get('object_checkpoint')
            packed = pack_from_benchmark(Path(report['stages']['seed']), Path(report['stages']['trace']),
                                         grouped, jobs=args.pack_jobs, object_checkpoint=Path(objects) if objects else None)
            record_pack(packed)
            stage = 'reopen'
            with canonical_bundle_lease(BUNDLE):
                if interrupted_pack is not None:
                    verify_compatible_publication(saved['production'], publication())
                    traced, reopened = verify_pair(packed, 'verify-trace')
                else:
                    pins = seeded['inputs'] | image_pin(packed)
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
    save_workflow_receipt(report_path, report)
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
    checkpoint.add_argument('--resume-pack', type=Path, help='results.json from an interrupted pack in --cache-work')
    checkpoint.add_argument('--verify-packed', type=Path, help='results.json from completed packing in --cache-work')
    parser.add_argument('--pack-jobs', type=int, default=1, help='maximum concurrent C compilers while packing')
    parser.add_argument('--object-checkpoint', type=Path, help='private directory for saving and reusing packed objects')
    parser.add_argument('--memory-guard-registry', type=Path, required=True)
    parser.add_argument('--adblock-assets', type=Path)
    parser.add_argument('--raster-parity-options', action='store_true')
    parser.add_argument('--settle-seconds', type=float, default=1)
    parser.add_argument('--timeout', type=float, default=180, help='browser timeout per visit in seconds')
    args = parser.parse_args()
    if not 0 <= args.settle_seconds < args.timeout:
        parser.error('Require a settle period below the browser timeout')
    if args.pack_jobs < 1 or (args.verify_packed and args.pack_jobs != 1):
        parser.error('--pack-jobs requires a positive compiler count and a packing run')
    if args.verify_packed and args.object_checkpoint:
        parser.error('--object-checkpoint requires a packing run')
    try:
        return run(args)
    except (OSError, ValueError) as error:
        print(f'Grouped LibJS cache: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
