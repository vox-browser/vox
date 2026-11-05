#!/usr/bin/env python3
"""Verify region-probe process ownership through the real memory guard on macOS."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SMOKE = r'''
#include <sys/mman.h>
#include <stdint.h>
int main(void) {
    size_t size = 512 * 1024;
    volatile uint8_t *p = mmap(0, size, PROT_READ | PROT_WRITE,
        MAP_ANON | MAP_PRIVATE, -1, 0);
    if ((void *)p == MAP_FAILED) return 2;
    p[0] = 1; p[size - 1] = 2;
    void *reset = mmap((void *)p, size, PROT_READ | PROT_WRITE,
        MAP_ANON | MAP_PRIVATE | MAP_FIXED, -1, 0);
    if (reset != (void *)p || p[0] || p[size - 1]) return 3;
    return munmap((void *)p, size) ? 4 : 0;
}
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if sys.platform != 'darwin':
        print('Region interposition requires macOS.')
        return 77
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    source = out / 'smoke.c'
    source.write_text(SMOKE)
    probe = out / 'region_probe.dylib'
    executable = out / 'region-probe-smoke'

    def guarded(label, command, env=None, runtime=False):
        receipt = out / (label + '-guard.json')
        call = [sys.executable, str(ROOT / 'tools/run_memory_bounded.py'),
                '--timeout', '60', '--lock', str(out / (label + '.lock')),
                '--report', str(receipt)]
        if runtime:
            call += ['--limit-gib', '3']
        result = subprocess.run(call + ['--'] + command, cwd=ROOT,
                                env=env, capture_output=True, text=True)
        (out / (label + '.log')).write_text(result.stdout + result.stderr)
        report = json.loads(receipt.read_text())
        assert result.returncode == 0 and report['child_exit_code'] == 0, label

    guarded('compile-probe', ['clang', '-O2', '-dynamiclib',
            str(ROOT / 'tools/prealloc_region_probe.c'), '-o', str(probe)])
    guarded('compile-smoke', ['clang', '-O0', str(source), '-o', str(executable)])
    env = dict(os.environ, DYLD_INSERT_LIBRARIES=str(probe))
    trace = out / 'mappings.txt'
    env.update(VOX_REGION_SAMPLE_OUT=str(trace),
               VOX_REGION_SAMPLE_PROCESS=executable.name)
    # Inherit the preload in both the Python guard and its child. Only the
    # selected executable may open the exclusive output, even though the guard
    # runs first and uses the same environment.
    guarded('run-selected', [str(executable)], env=env, runtime=True)
    lines = trace.read_text().splitlines()
    target = [line for line in lines if line.startswith('# executable ')]
    assert len(target) == 1 and target[0].endswith(' ' + str(executable)), target
    events = [line.split() for line in lines if line.startswith(('M ', 'U '))]
    assert len(events) == 2, events
    assert events[0][0] == 'M' and events[1][0] == 'U', events
    assert events[0][1:3] == events[1][1:3], events
    assert int(events[0][2]) == 512 * 1024 and len(events[0]) > 4, events
    skipped = out / 'not-selected.txt'
    env.update(VOX_REGION_SAMPLE_OUT=str(skipped),
               VOX_REGION_SAMPLE_PROCESS='not-this-process')
    guarded('run-not-selected', [str(executable)], env=env, runtime=True)
    assert not skipped.exists()
    print('Passed: target ownership, map/unmap stacks, fixed-map discard, and non-target exclusion.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
