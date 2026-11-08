#!/usr/bin/env python3
"""Check native deadline resets without repeated run-loop registration."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    paths = [Path(__file__), ROOT / 'tools/native_timer_restart_test.c',
             ROOT / 'platform/timer_host_bridge.h', ROOT / 'platform/zero_timer_dispatch.h']
    def hashes():
        return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    before = hashes()
    records = []
    for mode in ['optimized', 'sanitized']:
        binary = output / mode
        flags = ['-O2'] if mode == 'optimized' else ['-O1', '-g', '-fsanitize=address,undefined']
        compile_command = ['clang', '-std=c11', *flags, '-fblocks', '-Wall', '-Wextra',
                           '-Werror', '-Wno-unused-function', str(paths[1]),
                           '-framework', 'CoreFoundation', '-o', str(binary)]
        for stage, command, limit in [('compile', compile_command, 12), ('runtime', [str(binary)], 3)]:
            name = mode + '-' + stage
            guarded = [sys.executable, str(ROOT / 'tools/run_memory_bounded.py'),
                       '--lock', str(output / (name + '.lock')),
                       '--report', str(output / (name + '-guard.json')),
                       '--limit-gib', str(limit), '--', *command]
            with (output / (name + '.log')).open('w') as log:
                result = subprocess.run(guarded, stdout=log, stderr=subprocess.STDOUT,
                                        env=dict(os.environ, ASAN_OPTIONS='detect_leaks=0',
                                                 UBSAN_OPTIONS='halt_on_error=1'))
            records.append(dict(name=name, command=guarded, exit=result.returncode))
            (output / 'commands.json').write_text(json.dumps(records, indent=2) + '\n')
            result.check_returncode()
            if before != hashes():
                raise RuntimeError('Timer inputs changed during checks')
    (output / 'receipt.json').write_text(json.dumps(dict(passed=True, sources=before,
                                                       commands=records), indent=2) + '\n')
    print('Native timer restart: optimized and ASan/UBSan checks passed')


if __name__ == '__main__':
    main()
