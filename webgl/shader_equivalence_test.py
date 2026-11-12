#!/usr/bin/env python3
"""Compare native OpenGL shader acceptance and exact pixels with pinned ANGLE."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate-ref', required=True)
    parser.add_argument('--baseline-ref', default='29a715d1f6219ecfa890d4458dc1048f18d658ef')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('The native comparison requires Apple OpenGL and an installed ANGLE')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    paths = [Path(__file__).resolve(), ROOT / 'webgl/shader_equivalence_test.c',
             ROOT / 'webgl/native_gl_shader.h', ROOT / 'webgl/native_gl_shader_validation.h',
             ROOT / 'platform/native_state.h', ROOT / 'tools/run_memory_bounded.py']
    prefix = Path(subprocess.check_output(['brew', '--prefix', 'glslang'], text=True).strip())
    paths += [prefix / 'lib/libglslang.dylib', prefix / 'lib/libglslang-default-resource-limits.dylib',
              Path('/opt/homebrew/lib/libEGL.dylib'), Path('/opt/homebrew/lib/libGLESv2.dylib')]
    pins = {str(path): sha(path) for path in paths}
    report = dict(pins=pins, baseline_ref=args.baseline_ref, candidate_ref=args.candidate_ref,
                  host=dict(cpu_count=os.cpu_count(), load=os.getloadavg()), jobs={}, passed=False)

    def guarded(label, command, runtime=False):
        guard = [sys.executable, str(ROOT / 'tools/run_memory_bounded.py'),
                 '--lock', str(output / (label + '.lock')),
                 '--report', str(output / (label + '-guard.json')), '--timeout', '120']
        if runtime:
            guard += ['--limit-gib', '3']
        result = subprocess.run([*guard, '--', *command], cwd=ROOT, capture_output=True, text=True)
        report['jobs'][label] = dict(command=command, exit=result.returncode,
                                    stdout=result.stdout, stderr=result.stderr)
        (output / (label + '.log')).write_text(result.stdout + result.stderr)
        return result

    with tempfile.TemporaryDirectory(prefix='vox-shader-compare-') as temporary:
        temporary = Path(temporary)
        for engine, revision, headers in [
            ('angle', args.baseline_ref, ['native_egl.h', 'angle_dispatch_darwin.h', 'angle_procedures_linux.h']),
            ('native', args.candidate_ref, ['native_egl.h', 'native_egl_api.h', 'native_gl_platform.h',
                'native_gl_bounds.h', 'native_gl_compat.h', 'native_gl_readback.h',
                'native_gl_draw.h', 'native_gl_dispatch_windows.h']),
        ]:
            roots = []
            for name in headers:
                data = subprocess.check_output(['git', 'show', revision + ':webgl/' + name], cwd=ROOT)
                fixture = temporary / (engine + '-' + name)
                fixture.write_bytes(data)
                report.setdefault('git_inputs', {})[engine + '/' + name] = hashlib.sha256(data).hexdigest()
                roots.append(dict(type='file', name=str(ROOT / 'webgl' / name),
                                  **{'external-contents': str(fixture)}))
            overlay = temporary / (engine + '-overlay.json')
            overlay.write_text(json.dumps(dict(version=0, roots=roots, **{'use-external-names': False})))
            flags = (shlex.split(subprocess.check_output(['pkg-config', '--cflags', 'egl', 'glesv2'], text=True))
                     + ['-Wl,-rpath,/opt/homebrew/lib', '-Wno-non-literal-null-conversion'] if engine == 'angle' else
                     ['-framework', 'OpenGL', '-I' + str(prefix / 'include'),
                      '-Wl,-rpath,' + str(prefix / 'lib'), '-Wno-deprecated-declarations'])
            binary = temporary / engine
            command = ['clang', '-std=c11', '-Werror=implicit-function-declaration',
                       '-Werror=incompatible-pointer-types', '-I' + str(ROOT / 'webgl'),
                       '-ivfsoverlay', str(overlay), *flags,
                       str(ROOT / 'webgl/shader_equivalence_test.c'), '-o', str(binary)]
            build = guarded(engine + '-compile', command)
            if build.returncode:
                continue
            report['jobs'][engine + '-compile']['binary_sha256'] = sha(binary)
            run = guarded(engine + '-runtime', [str(binary)], runtime=True)
            try:
                report.setdefault('observations', {})[engine] = [json.loads(line) for line in run.stdout.splitlines()]
            except json.JSONDecodeError:
                report['parse_error'] = engine
        observations = report.get('observations', {})
        changed = [name for name, digest in pins.items() if sha(Path(name)) != digest]
        report['changed_inputs'] = changed
        if set(observations) == {'angle', 'native'}:
            report['equivalent'] = observations['angle'] == observations['native']
            report['passed'] = (report['equivalent'] and not changed
                and all(row['exit'] == 0 for row in report['jobs'].values())
                and observations['native'][-1].get('failed') == 0)
        (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(dict(passed=report['passed'], result=str(output / 'result.json'))))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
