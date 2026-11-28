#!/usr/bin/env python3
"""Repeat first/reopened GitHub initialization in fresh processes/private caches.

Run through run_memory_bounded --limit-gib 3. This retains incomplete-load
diagnostics; timing a failed GitHub hydration is never a page-speed acceptance.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import statistics
import subprocess
import time


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def host():
    return dict(unix=time.time(), cpu_count=os.cpu_count(), load=os.getloadavg())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--pairs', type=int, default=7)
    args = parser.parse_args()
    if args.pairs < 7:
        parser.error('Retain at least seven complete first/reopen pairs')
    binary, archive, output = (p.resolve() for p in (args.binary, args.archive, args.output))
    output.mkdir(parents=True, exist_ok=False)
    mapping = json.loads((archive / 'source-map.json').read_text())
    paths = [binary, archive / 'manifest.json', archive / 'source-map.json',
             *(Path(p).resolve() for p in mapping.values())]
    pins = {str(path): digest(path) for path in paths}
    environment = {k: v for k, v in os.environ.items()
                   if not k.startswith(('VOX_', 'LADYBIRD_', 'JSC_', 'DYLD_', 'GC_'))
                   and 'proxy' not in k.lower()}
    report = dict(scope='offline native DOM/author-script first and reopened initialization; no rendering or successful-hydration claim',
                  inputs=pins, host_before=host(), attempts=[], complete_page_load=False)

    def save():
        (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')

    def verify():
        changed = [p for p, expected in pins.items()
                   if not Path(p).is_file() or digest(Path(p)) != expected]
        if changed:
            raise RuntimeError(f'Pinned inputs changed: {changed}')

    try:
        for index in range(args.pairs):
            verify()
            cache = output / f'pair-{index + 1}-cache'
            command = [str(binary), str(archive), str(cache), '2']
            attempt = dict(command=command, host_before=host())
            report['attempts'].append(attempt)
            save()
            began = time.monotonic_ns()
            try:
                process = subprocess.run(command, capture_output=True, text=True,
                                         env=environment, timeout=180)
                attempt.update(exit=process.returncode, stdout=process.stdout, stderr=process.stderr)
                if process.returncode:
                    raise RuntimeError(f'Pair {index + 1} exited {process.returncode}')
                visits = [json.loads(line) for line in process.stdout.splitlines() if line.startswith('{')]
                attempt['visits'] = visits
                if len(visits) != 2:
                    raise RuntimeError('Expected exactly two visit receipts')
                first, second = visits
                for visit in visits:
                    if visit['timeout'] or visit['jsc_initialized'] or visit['rows'] != 33:
                        raise RuntimeError('Invalid document/engine identity')
                    if 'GitHub - vlang/v' not in visit['title'] or visit['cache']['last_error']:
                        raise RuntimeError('Document or code cache failed')
                for key in ['title', 'rows', 'commit_links', 'initial_errors', 'module_errors', 'javascript_messages']:
                    if first[key] != second[key]:
                        raise RuntimeError(f'Behavior changed on reopen: {key}')
                if (first['cache']['compiler_invocations'] < 1
                        or first['frontend']['misses'] < 1
                        or second['cache']['compiler_invocations'] != 0
                        or second['cache']['cache_misses'] != 0
                        or second['frontend']['misses'] != 0
                        or second['cache']['cache_hits'] != first['cache']['compiled_executables']
                        or second['frontend']['hits'] != first['frontend']['misses']):
                    raise RuntimeError('The second visit did not completely reuse the compiled/parsed cohort')
                attempt['native_libraries'] = {str(p): digest(p) for p in cache.rglob('*.dylib')}
                if not attempt['native_libraries']:
                    attempt['native_libraries'] = {str(p): digest(p) for p in cache.rglob('*.so')}
                verify()
                print(f"pair {index + 1}: {first['total_ms']:.3f} -> {second['total_ms']:.3f} ms; "
                      f"native hits {second['cache']['cache_hits']}; frontend hits {second['frontend']['hits']}", flush=True)
            except Exception as error:
                attempt['error'] = str(error)
                raise
            finally:
                attempt.update(wall_ns=time.monotonic_ns() - began, host_after=host())
                save()
        first_ms = [a['visits'][0]['total_ms'] for a in report['attempts']]
        second_ms = [a['visits'][1]['total_ms'] for a in report['attempts']]
        report['summary'] = dict(first_ms=first_ms, second_ms=second_ms,
            first_median_ms=statistics.median(first_ms), second_median_ms=statistics.median(second_ms),
            median_pair_ratio=statistics.median(b / a for a, b in zip(first_ms, second_ms)),
            conservative_ratio=max(second_ms) / min(first_ms))
        report['cache_workflow_verified'] = True
        report['complete_page_load'] = all(not v['initial_errors'] and not v['module_errors']
            and not v['javascript_messages'] and v['commit_links'] > 0
            for a in report['attempts'] for v in a['visits'])
        report['speed_acceptance'] = False
        print(json.dumps(report['summary'], indent=2))
    finally:
        report['host_after'] = host()
        save()


if __name__ == '__main__':
    main()
