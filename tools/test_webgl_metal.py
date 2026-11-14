#!/usr/bin/env python3
"""Exercise direct Metal resources without loading ANGLE, with ARC/MRC and sanitizers."""
import argparse
import atexit
import os
import tempfile
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
    parser.add_argument('--v-bin', type=Path, default=Path.home() / 'code/v/v')
    parser.add_argument('--native-only', action='store_true', help='Run the C ABI fixtures without the additional V test files')
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('Direct Metal tests require macOS with a Metal device')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    inputs = [Path(__file__).resolve(), ROOT / 'tools/run_memory_bounded.py',
              *sorted((ROOT / 'webgl/shader').glob('*.v')),
              *sorted((ROOT / 'webgl/metal').glob('*.h')), *sorted((ROOT / 'webgl/metal').glob('*.m')), *sorted((ROOT / 'webgl/metal').glob('*.v'))]
    if args.v_bin:
        args.v_bin = args.v_bin.expanduser().resolve()
        if not args.v_bin.is_file():
            parser.error('V compiler not found: ' + str(args.v_bin))
        inputs.append(args.v_bin)
    pins = {str(path): digest(path) for path in inputs}
    report = dict(pins=pins, jobs=[], passed=False)
    for suite in ['drawing_buffer', 'shader_program', 'render', 'texture', 'render_state', 'vertex', 'feedback', 'uniform_struct', 'shader_loading']:
        for mode, flags in [('arc', ['-fobjc-arc', '-O2']),
                            ('mrc', ['-fno-objc-arc', '-O2']),
                            ('sanitized', ['-fobjc-arc', '-O1', '-g', '-fsanitize=address,undefined'])]:
            binary = output / (suite + '-' + mode)
            descriptor, name = tempfile.mkstemp(prefix='native_suite_', suffix='_test.v', dir=ROOT / 'webgl/metal')
            os.close(descriptor)
            entry = Path(name)
            atexit.register(entry.unlink, missing_ok=True)
            entry.write_text('module metal\n#define main vox_native_suite_main\n#include "@DIR/' + suite + '_test.m"\n#undef main\nfn C.vox_native_suite_main() i32\nfn test_native_suite() { assert C.vox_native_suite_main() == 0 }\n')
            compiler = [str(args.v_bin), '-new-compiler', '-skip-running', '-b', 'c', '-cc', 'clang',
                        '-memory-limit', '10G', '-enable-globals', '-cflags', ' '.join(flags),
                        *(['-ldflags', '-fsanitize=address,undefined'] if mode == 'sanitized' else []),
                        '-o', str(binary), str(entry)]
            for phase, command in [('compile', compiler), ('runtime', [str(binary)])]:
                label = suite + '-' + mode + '-' + phase
                guard = [sys.executable, str(ROOT / 'tools/run_memory_bounded.py'),
                         '--limit-gib', '3' if phase == 'runtime' else '12',
                         '--timeout', '120', '--lock', str(output / (label + '.lock')),
                         '--report', str(output / (label + '.json')), '--', *command]
                result = subprocess.run(guard, cwd=ROOT, env=dict(os.environ, V_MACOS_V3_NO_FALLBACK='1'), capture_output=True, text=True)
                report['jobs'].append(dict(suite=suite, mode=mode, phase=phase, command=command,
                    exit=result.returncode, stdout=result.stdout, stderr=result.stderr))
                (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
                if result.returncode:
                    print(result.stdout + result.stderr)
                    return result.returncode
            entry.unlink()
            print(suite + ' ' + mode + ': passed', flush=True)
    if not args.native_only:
        for test in sorted((ROOT / 'webgl/metal').glob('*_test.v')):
            for gc, flags in [('default', []), ('none', ['-gc', 'none'])]:
                binary = output / (test.stem + '-' + gc)
                compiler = [str(args.v_bin), '-new-compiler', '-skip-running', '-b', 'c', '-cc', 'clang',
                            '-cflags', '-O0', '-memory-limit', '10G', '-enable-globals', *flags,
                            '-o', str(binary), str(test)]
                for phase, command in [('compile', compiler), ('runtime', [str(binary)])]:
                    label = test.stem + '-' + gc + '-' + phase
                    guard = [sys.executable, str(ROOT / 'tools/run_memory_bounded.py'),
                             '--limit-gib', '3' if phase == 'runtime' else '12',
                             '--timeout', '300', '--lock', str(output / (label + '.lock')),
                             '--report', str(output / (label + '.json')), '--', *command]
                    result = subprocess.run(guard, cwd=ROOT, env=dict(os.environ, V_MACOS_V3_NO_FALLBACK='1'), capture_output=True, text=True)
                    report['jobs'].append(dict(suite=test.stem, mode=gc, phase=phase,
                        command=command, exit=result.returncode, stdout=result.stdout, stderr=result.stderr))
                    (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
                    if result.returncode:
                        print(result.stdout + result.stderr)
                        return result.returncode
                print(test.name + ' gc=' + gc + ': passed', flush=True)
    report['changed_inputs'] = [name for name, pin in pins.items() if digest(Path(name)) != pin]
    report['passed'] = not report['changed_inputs']
    (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
