#!/usr/bin/env python3
"""Exercise native GIF capture policy with the real AppKit decoder."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'Build' / ('image-capture-policy-' + str(time.time_ns())))
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    inputs = [ROOT / p for p in ['native/include/native_image_capture_policy_darwin.h',
              'tools/native_image_capture_policy_test.mm', 'Tests/Browser/Brave/resources/two-frame-capture.gif']]
    identity = lambda: {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    before = identity()
    (out / 'inputs.json').write_text(json.dumps(before, indent=2) + '\n')
    environment = dict(os.environ, ASAN_OPTIONS='detect_leaks=0')
    for name, flags in [('optimized', ['-O2']), ('sanitized', ['-O1', '-g', '-fsanitize=address,undefined', '-fno-omit-frame-pointer'])]:
        binary = out / name
        compile = ['clang++', '-std=c++20', *flags, '-framework', 'Cocoa', str(inputs[1]), '-o', str(binary)]
        for phase, command, limit in [('compile', compile, '12'), ('run', [str(binary), str(inputs[2])], '3')]:
            prefix = out / (name + '-' + phase)
            guard = [sys.executable, str(ROOT / 'tools/run_memory_bounded.py'), '--limit-gib', limit,
                     '--lock', str(prefix) + '.lock', '--report', str(prefix) + '.json', '--', *command]
            with Path(str(prefix) + '.log').open('w') as log:
                subprocess.run(guard, cwd=ROOT, env=environment, stdout=log, stderr=subprocess.STDOUT, check=True)
            if identity() != before:
                raise RuntimeError('GIF policy test inputs changed')
    print('Native image capture policy passes optimized and sanitized; evidence: ' + str(out))


if __name__ == '__main__':
    main()
