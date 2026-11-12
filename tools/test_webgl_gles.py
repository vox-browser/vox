#!/usr/bin/env python3
"""Exercise native Linux EGL/GLES WebGL without ANGLE, including CPU bounds."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import select
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def host_runtime(arguments):
    # Own and reap Xvfb explicitly: xvfb-run sends SIGTERM without waiting,
    # which can leave its server alive past the runtime guard's endpoint.
    read_fd, write_fd = os.pipe()
    server = subprocess.Popen(['Xvfb', '-displayfd', str(write_fd), '-screen', '0',
                               '640x480x24', '-nolisten', 'tcp'], pass_fds=(write_fd,),
                              stdout=subprocess.DEVNULL)
    os.close(write_fd)
    try:
        if not select.select([read_fd], [], [], 10)[0]:
            raise RuntimeError('Xvfb did not publish its display')
        display = os.read(read_fd, 64).decode().strip()
        if not display.isdigit():
            raise RuntimeError('Xvfb failed to initialize')
        return subprocess.run(arguments, env=dict(os.environ, DISPLAY=':' + display)).returncode
    finally:
        os.close(read_fd)
        server.terminate()
        try:
            server.wait(timeout=10)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait()


def main():
    if len(sys.argv) > 1 and sys.argv[1] == '--host-runtime':
        return host_runtime(sys.argv[2:])
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if sys.platform != 'linux':
        parser.error('Run on Linux with a GLES3 driver (Mesa software rendering is supported)')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    inputs = [Path(__file__).resolve(), ROOT / 'tools/native_gles_linux_test.c', ROOT / 'tools/native_gles_host_linux_test.c',
              ROOT / 'tools/run_memory_bounded.py', ROOT / 'tools/native_gles_glx.lsan-suppressions', ROOT / 'platform/native_state.h',
              ROOT / 'webgl/native_egl.h', ROOT / 'webgl/native_gl_shader_validation.h',
              ROOT / 'webgl/essl_desktop_translation.h', *sorted((ROOT / 'webgl').glob('gles_*_linux.h'))]
    pins = {str(p): digest(p) for p in inputs}
    flags = shlex.split(subprocess.check_output(['pkg-config', '--cflags', '--libs', 'egl', 'glesv2', 'gl', 'x11', 'glslang'], text=True))
    report = dict(pins=pins, jobs=[], passed=False)
    environment = dict(os.environ, LIBGL_ALWAYS_SOFTWARE='1')
    # Keep leak checking enabled. The GLX fixtures alone suppress Mesa's
    # visual/config cache, independently reproduced by the host-only control.
    for mode, options in [('release', ['-O2']), ('sanitized', ['-O1', '-g', '-fsanitize=address,undefined', '-fno-omit-frame-pointer'])]:
        for fixture in ('headless', 'host-only', 'host'):
            label = mode + '-' + fixture
            binary = output / label
            source = 'native_gles_host_linux_test.c' if fixture != 'headless' else 'native_gles_linux_test.c'
            command = [os.environ.get('CC', 'clang'), '-std=c11', '-Werror', '-Wno-unused-function',
                       *options, str(ROOT / 'tools' / source), '-o', str(binary),
                       *flags, '-lglslang-default-resource-limits', '-lstdc++', '-lm', '-ldl']
            runtime = [str(binary)]
            runtime_environment = dict(environment)
            if fixture != 'headless':
                runtime = [sys.executable, str(Path(__file__).resolve()), '--host-runtime', str(binary)] + (['--host-only'] if fixture == 'host-only' else [])
                runtime_environment['LSAN_OPTIONS'] = 'suppressions=' + str(ROOT / 'tools/native_gles_glx.lsan-suppressions')
            for phase, invocation in [('compile', command), ('runtime', runtime)]:
                job_label = label + '-' + phase
                guard = [sys.executable, str(ROOT / 'tools/run_memory_bounded.py'), '--limit-gib',
                         '12' if phase == 'compile' else '3', '--timeout', '180',
                         '--lock', str(output / (job_label + '.lock')), '--report', str(output / (job_label + '.json')),
                         '--', *invocation]
                run = subprocess.run(guard, cwd=ROOT, env=runtime_environment, capture_output=True, text=True)
                (output / (job_label + '.log')).write_text(run.stdout + run.stderr)
                report['jobs'].append(dict(mode=mode, fixture=fixture, phase=phase, command=invocation, exit=run.returncode))
                report['changed_inputs'] = [name for name, value in pins.items() if digest(Path(name)) != value]
                (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
                if run.returncode or report['changed_inputs']:
                    print(run.stdout + run.stderr)
                    return run.returncode or 1
            print(label + ': passed', flush=True)
    report['passed'] = True
    (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
