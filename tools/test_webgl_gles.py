#!/usr/bin/env python3
"""Exercise native Linux EGL/GLES WebGL without ANGLE, including CPU bounds."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if sys.platform != 'linux':
        parser.error('Run on Linux with a GLES3 driver (Mesa software rendering is supported)')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    inputs = [Path(__file__).resolve(), ROOT / 'tools/native_gles_linux_test.c',
              ROOT / 'tools/run_memory_bounded.py', ROOT / 'platform/native_state.h',
              ROOT / 'webgl/native_egl.h', ROOT / 'webgl/native_gl_shader_validation.h',
              ROOT / 'webgl/essl_desktop_translation.h', *sorted((ROOT / 'webgl').glob('gles_*_linux.h'))]
    pins = {str(p): digest(p) for p in inputs}
    flags = shlex.split(subprocess.check_output(['pkg-config', '--cflags', '--libs', 'egl', 'glesv2', 'glslang'], text=True))
    report = dict(pins=pins, jobs=[], passed=False)
    environment = dict(os.environ, LIBGL_ALWAYS_SOFTWARE='1')
    # Mesa and LLVM own process-global allocations; retain default sanitizer
    # settings so real failures, including leaks, remain visible.
    for mode, options in [('release', ['-O2']), ('sanitized', ['-O1', '-g', '-fsanitize=address,undefined', '-fno-omit-frame-pointer'])]:
        binary = output / mode
        command = [os.environ.get('CC', 'clang'), '-std=c11', '-Werror', '-Wno-unused-function',
                   *options, str(ROOT / 'tools/native_gles_linux_test.c'), '-o', str(binary),
                   *flags, '-lglslang-default-resource-limits', '-lstdc++', '-lm']
        for phase, invocation in [('compile', command), ('runtime', [str(binary)])]:
            label = mode + '-' + phase
            guard = [sys.executable, str(ROOT / 'tools/run_memory_bounded.py'), '--limit-gib',
                     '12' if phase == 'compile' else '3', '--timeout', '180',
                     '--lock', str(output / (label + '.lock')), '--report', str(output / (label + '.json')),
                     '--', *invocation]
            run = subprocess.run(guard, cwd=ROOT, env=environment, capture_output=True, text=True)
            (output / (label + '.log')).write_text(run.stdout + run.stderr)
            report['jobs'].append(dict(mode=mode, phase=phase, command=invocation, exit=run.returncode))
            report['changed_inputs'] = [name for name, value in pins.items() if digest(Path(name)) != value]
            (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
            if run.returncode or report['changed_inputs']:
                print(run.stdout + run.stderr)
                return run.returncode or 1
        print(mode + ': passed', flush=True)
    report['passed'] = True
    (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
