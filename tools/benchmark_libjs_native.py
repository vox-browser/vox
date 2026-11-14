#!/usr/bin/env python3
"""Alternate fresh-process LibJS interpreter/native HN callback measurements.

Run this driver through run_memory_bounded (3 GiB). It is an engine/DOM
experiment, not a browser launch, rendering, instruction-count or Brave gate.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import statistics
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'Tests/Browser/Brave/hn-home-instructions/bodies/2e38ff883bd36dc4cc26f129f19169b0357cf32059988c926a4f73e5bfaa37f0'
PAGE = ROOT / 'Tests/Browser/Brave/input/hacker-news-item-50231722-complete.html'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def host():
    return dict(unix=time.time(), cpu_count=os.cpu_count(), load=os.getloadavg())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--pairs', type=int, default=7)
    parser.add_argument('--cycles', type=int, default=200)
    parser.add_argument('--warmup', type=int, default=8)
    parser.add_argument('--timeout', type=float, default=120)
    args = parser.parse_args()
    if args.pairs < 7 or min(args.cycles, args.warmup) < 1:
        parser.error('Use at least seven pairs and positive cycle counts')
    output, binary = args.output.resolve(), args.binary.resolve()
    output.mkdir(parents=True, exist_ok=False)
    cache = output / 'cache'
    environment = {k: v for k, v in os.environ.items()
                   if not k.startswith(('VOX_', 'LADYBIRD_', 'JSC_', 'GC_', 'DYLD_', 'VFLAGS'))
                   and 'proxy' not in k.lower()}
    pins = {str(path): digest(path) for path in (binary, SCRIPT, PAGE)}
    # Pin explicit Homebrew/native dynamic dependencies too. System shared-cache
    # libraries have no standalone readable file; retain the complete load list.
    linked = subprocess.run(['/usr/bin/otool', '-L', str(binary)],
                            capture_output=True, text=True, check=True).stdout
    for line in linked.splitlines()[1:]:
        path = Path(line.strip().split(' (', 1)[0])
        if path.is_absolute() and path.is_file():
            pins[str(path)] = digest(path)
    report = dict(scope='HN script + native DOM callbacks; no browser layout/paint/network',
                  inputs=pins, linked_libraries=linked, host_before=host(), attempts=[])

    def save():
        (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')

    def verify():
        changed = [p for p, expected in pins.items()
                   if not Path(p).is_file() or digest(Path(p)) != expected]
        if changed:
            raise RuntimeError(f'Inputs changed: {changed}')

    def run(mode, label):
        verify()
        command = [str(binary), mode, str(cache), str(args.cycles), str(args.warmup)]
        attempt = dict(label=label, command=command, host_before=host())
        report['attempts'].append(attempt)
        save()
        began = time.monotonic_ns()
        try:
            process = subprocess.run(command, capture_output=True, text=True,
                                     env=environment, cwd=ROOT, timeout=args.timeout)
            attempt.update(exit=process.returncode, stdout=process.stdout, stderr=process.stderr)
            if process.returncode:
                raise RuntimeError(f'{label} exited {process.returncode}')
            result = json.loads(process.stdout.strip().splitlines()[-1])
            attempt['result'] = result
            if (not result['collapse_verified'] or not result['classes_restored']
                    or result['comment_rows'] != 101
                    or result['cycles'] != args.cycles or result['warmup_cycles'] != args.warmup
                    or result['script_sha256'] != pins[str(SCRIPT)]
                    or result['page_sha256'] != pins[str(PAGE)]):
                raise RuntimeError(f'{label} failed its workload/content audit')
            native = result['native']
            library = native['library']
            if library not in pins:
                if label != 'eligibility':
                    raise RuntimeError(f'{label} generated unexpected native code')
                pins[library] = native['library_sha256']
            if native['library_sha256'] != pins[library]:
                raise RuntimeError(f'{label} loaded changed native code')
            if mode == 'diagnostic':
                if not all(result['activity'][key] > 0 for key in ('entries', 'fast_steps', 'slow_steps')):
                    raise RuntimeError('Native tier did not exercise both native and dynamic operations')
            elif (not native['cache_hit'] or any(result['activity'].values())):
                raise RuntimeError('Timed run compiled code or enabled diagnostic counters')
            verify()
            print(f"{label}: {result['elapsed_ns'] / 1e6:.3f} ms", flush=True)
            return result
        except Exception as error:
            attempt['error'] = str(error)
            raise
        finally:
            attempt.update(wall_ns=time.monotonic_ns() - began, host_after=host())
            save()

    try:
        run('diagnostic', 'eligibility')
        control, native, ratios = [], [], []
        for index in range(args.pairs):
            order = ['control', 'native'] if index % 2 == 0 else ['native', 'control']
            pair = {mode: run(mode, f'pair-{index + 1}-{mode}') for mode in order}
            control.append(pair['control']['elapsed_ns'])
            native.append(pair['native']['elapsed_ns'])
            ratios.append(pair['native']['elapsed_ns'] / pair['control']['elapsed_ns'])
        report['summary'] = dict(control_ns=control, native_ns=native,
            control_median_ms=statistics.median(control) / 1e6,
            native_median_ms=statistics.median(native) / 1e6,
            median_pair_ratio=statistics.median(ratios),
            ratio_of_medians=statistics.median(native) / statistics.median(control),
            conservative_ratio=max(native) / min(control))
        report['valid'] = True
        print(json.dumps(report['summary'], indent=2))
    except Exception as error:
        report.update(valid=False, error=str(error))
        raise
    finally:
        report['host_after'] = host()
        save()


if __name__ == '__main__':
    main()
