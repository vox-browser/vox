#!/usr/bin/env python3
"""Exercise direct Metal resources without loading ANGLE, with ARC/MRC and sanitizers."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('Direct Metal tests require macOS with a Metal device')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    inputs = [Path(__file__).resolve(), ROOT / 'webgl/metal/drawing_buffer_darwin.h',
              ROOT / 'webgl/metal/drawing_buffer_test.m', ROOT / 'tools/run_memory_bounded.py']
    pins = {str(path): digest(path) for path in inputs}
    report = dict(pins=pins, jobs=[], passed=False)
    for mode, flags in [('arc', ['-fobjc-arc', '-O2']),
                        ('mrc', ['-fno-objc-arc', '-O2']),
                        ('sanitized', ['-fobjc-arc', '-O1', '-g', '-fsanitize=address,undefined'])]:
        binary = output / mode
        compiler = ['clang', '-std=c11', *flags, '-Werror', '-framework', 'Foundation',
                    '-framework', 'Metal', '-framework', 'CoreFoundation',
                    str(ROOT / 'webgl/metal/drawing_buffer_test.m'), '-o', str(binary)]
        for phase, command in [('compile', compiler), ('runtime', [str(binary)])]:
            label = mode + '-' + phase
            guard = [sys.executable, str(ROOT / 'tools/run_memory_bounded.py'),
                     '--limit-gib', '3' if phase == 'runtime' else '12',
                     '--timeout', '120', '--lock', str(output / (label + '.lock')),
                     '--report', str(output / (label + '.json')), '--', *command]
            result = subprocess.run(guard, cwd=ROOT, capture_output=True, text=True)
            report['jobs'].append(dict(mode=mode, phase=phase, command=command,
                exit=result.returncode, stdout=result.stdout, stderr=result.stderr))
            (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
            if result.returncode:
                print(result.stdout + result.stderr)
                return result.returncode
        print(mode + ': passed', flush=True)
    report['changed_inputs'] = [name for name, pin in pins.items() if digest(Path(name)) != pin]
    report['passed'] = not report['changed_inputs']
    (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
