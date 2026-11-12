#!/usr/bin/env python3
"""Compile and execute direct Metal WebGL service tests under the memory guard."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--v-bin', type=Path, default=Path.home() / 'code/v/v')
    parser.add_argument('--gc', choices=['both', 'default', 'none'], default='both')
    parser.add_argument('--backend', choices=['c', 'fastc'], default='c')
    parser.add_argument('tests', nargs='*', type=Path)
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('The direct Metal backend requires macOS')
    compiler = args.v_bin.expanduser().resolve()
    if not compiler.is_file():
        parser.error('V compiler not found: ' + str(compiler))
    tests = [(ROOT / path).resolve() for path in args.tests] if args.tests else sorted(
        (ROOT / 'webgl').glob('service*_d_vox_direct_metal_test.v'))
    if not tests or any(not path.is_file() or not path.is_relative_to(ROOT) or
                        not path.name.endswith('_test.v') for path in tests):
        parser.error('Tests must be existing repository *_test.v files')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    inputs = {Path(__file__).resolve(), ROOT / 'tools/run_memory_bounded.py', compiler, *tests}
    for path in (ROOT / 'webgl').rglob('*'):
        if path.is_file() and path.suffix in ['.v', '.h', '.m'] and not path.name.endswith('_test.v'):
            inputs.add(path)
    pins = {str(path): digest(path) for path in sorted(inputs)}
    report = dict(pins=pins, jobs=[], passed=False)
    environment = os.environ.copy()
    if args.backend == 'fastc':
        environment['VJOBS'] = '1'  # Native header state must live in one FastC C unit.
    modes = ['default', 'none'] if args.gc == 'both' else [args.gc]
    for test in tests:
        for gc in modes:
            binary = output / (test.stem + '-' + gc)
            command = [str(compiler), '-w', '-new-compiler', '-skip-running', '-b', args.backend,
                       '-cc', 'clang', '-cflags', '-O0', '-memory-limit', '10G', '-enable-globals',
                       '-d', 'vox_direct_metal', *(['-gc', 'none'] if gc == 'none' else []),
                       '-o', str(binary), str(test)]
            for phase, invocation in [('compile', command), ('runtime', [str(binary)])]:
                label = test.stem + '-' + gc + '-' + phase
                guard = [sys.executable, str(ROOT / 'tools/run_memory_bounded.py'),
                         '--limit-gib', '12' if phase == 'compile' else '3',
                         '--timeout', '300' if phase == 'compile' else '120',
                         '--lock', str(output / (label + '.lock')),
                         '--report', str(output / (label + '.json')), '--', *invocation]
                result = subprocess.run(guard, cwd=ROOT, env=environment, text=True, capture_output=True)
                (output / (label + '.log')).write_text(result.stdout + result.stderr)
                report['jobs'].append(dict(test=str(test.relative_to(ROOT)), gc=gc, phase=phase,
                    command=invocation, exit=result.returncode))
                report['changed_inputs'] = [name for name, pin in pins.items() if digest(Path(name)) != pin]
                (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
                if result.returncode or report['changed_inputs']:
                    print(label + ': failed', flush=True)
                    print((result.stdout + result.stderr)[-12000:])
                    if report['changed_inputs']:
                        print('Inputs changed: ' + ', '.join(report['changed_inputs']))
                    return result.returncode or 1
            print(str(test.relative_to(ROOT)) + ' gc=' + gc + ': passed', flush=True)
    report['passed'] = True
    (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
