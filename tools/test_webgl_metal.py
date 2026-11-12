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
    parser.add_argument('--v-bin', type=Path, help='Also compile/run every V Metal test in default and no-GC modes')
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('Direct Metal tests require macOS with a Metal device')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    inputs = [Path(__file__).resolve(), ROOT / 'tools/run_memory_bounded.py',
              ROOT / 'webgl/essl_desktop_translation.h', ROOT / 'webgl/native_gl_shader_validation.h',
              *sorted((ROOT / 'webgl/metal').glob('*.h')), *sorted((ROOT / 'webgl/metal').glob('*.m')), *sorted((ROOT / 'webgl/metal').glob('*.v'))]
    if args.v_bin:
        args.v_bin = args.v_bin.expanduser().resolve()
        if not args.v_bin.is_file():
            parser.error('V compiler not found: ' + str(args.v_bin))
        inputs.append(args.v_bin)
    glslang = Path(subprocess.check_output(['brew', '--prefix', 'glslang'], text=True).strip())
    cross = Path(subprocess.check_output(['brew', '--prefix', 'spirv-cross'], text=True).strip())
    shader_flags = ['-I' + str(glslang / 'include'), '-I' + str(cross / 'include/spirv_cross'),
                    '-L' + str(cross / 'lib'), '-Wl,-rpath,' + str(glslang / 'lib'),
                    *['-lspirv-cross-' + name for name in ['c', 'msl', 'cpp', 'hlsl', 'reflect', 'glsl', 'core']], '-lc++']
    pins = {str(path): digest(path) for path in inputs}
    report = dict(pins=pins, jobs=[], passed=False)
    for suite in ['drawing_buffer', 'shader_program', 'render', 'texture', 'render_state', 'vertex', 'feedback', 'uniform_struct', 'shader_loading']:
        for mode, flags in [('arc', ['-fobjc-arc', '-O2']),
                            ('mrc', ['-fno-objc-arc', '-O2']),
                            ('sanitized', ['-fobjc-arc', '-O1', '-g', '-fsanitize=address,undefined'])]:
            binary = output / (suite + '-' + mode)
            compiler = ['clang', '-std=c11', *flags, '-Werror', '-framework', 'Foundation',
                        '-framework', 'Metal', '-framework', 'CoreFoundation',
                        str(ROOT / ('webgl/metal/' + suite + '_test.m')), '-o', str(binary),
                        *(shader_flags if suite != 'drawing_buffer' else [])]
            for phase, command in [('compile', compiler), ('runtime', [str(binary)])]:
                label = suite + '-' + mode + '-' + phase
                guard = [sys.executable, str(ROOT / 'tools/run_memory_bounded.py'),
                         '--limit-gib', '3' if phase == 'runtime' else '12',
                         '--timeout', '120', '--lock', str(output / (label + '.lock')),
                         '--report', str(output / (label + '.json')), '--', *command]
                result = subprocess.run(guard, cwd=ROOT, capture_output=True, text=True)
                report['jobs'].append(dict(suite=suite, mode=mode, phase=phase, command=command,
                    exit=result.returncode, stdout=result.stdout, stderr=result.stderr))
                (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
                if result.returncode:
                    print(result.stdout + result.stderr)
                    return result.returncode
            print(suite + ' ' + mode + ': passed', flush=True)
    if args.v_bin:
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
                    result = subprocess.run(guard, cwd=ROOT, capture_output=True, text=True)
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
