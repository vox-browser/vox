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
    inputs = [Path(__file__).resolve(), ROOT / 'tools/run_memory_bounded.py',
              ROOT / 'webgl/essl_desktop_translation.h', ROOT / 'webgl/native_gl_shader_validation.h',
              *sorted((ROOT / 'webgl/metal').glob('*.h')), *sorted((ROOT / 'webgl/metal').glob('*.m'))]
    glslang = Path(subprocess.check_output(['brew', '--prefix', 'glslang'], text=True).strip())
    cross = Path(subprocess.check_output(['brew', '--prefix', 'spirv-cross'], text=True).strip())
    shader_flags = ['-I' + str(glslang / 'include'), '-I' + str(cross / 'include/spirv_cross'),
                    '-L' + str(cross / 'lib'), '-Wl,-rpath,' + str(glslang / 'lib'),
                    str(glslang / 'lib/libglslang.dylib'),
                    str(glslang / 'lib/libglslang-default-resource-limits.dylib'),
                    *['-lspirv-cross-' + name for name in ['c', 'msl', 'cpp', 'hlsl', 'reflect', 'glsl', 'core']], '-lc++']
    pins = {str(path): digest(path) for path in inputs}
    report = dict(pins=pins, jobs=[], passed=False)
    for suite in ['drawing_buffer', 'shader_program', 'render']:
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
    report['changed_inputs'] = [name for name, pin in pins.items() if digest(Path(name)) != pin]
    report['passed'] = not report['changed_inputs']
    (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
