#!/usr/bin/env python3
"""Compare clipped tile batches and both rollback points with a pinned bridge.

Run through tools/run_memory_bounded.py with a 3 GiB cap. The existing native
fixture checks every pixel and row-padding byte across scales, fractional layer
origins, rectangle/ellipse clips, mixed MSAA, alpha and horizontal/vertical ink.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import tempfile


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference-library', type=Path, required=True)
    parser.add_argument('--graphite-dir', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    output = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix='vox-clipped-batch-'))
    output.mkdir(parents=True, exist_ok=True)
    assert not any(output.iterdir()), 'Refusing to overwrite earlier evidence'
    triplet = os.environ.get('LADYBIRD_VCPKG_TRIPLET',
                             'arm64-osx-dynamic' if platform.machine() == 'arm64' else 'x64-osx-dynamic')
    upstream = Path(os.environ.get('LADYBIRD_SOURCE_DIR', repo.parent / '3rd/ladybird'))
    skia = upstream / 'Build/release/vcpkg_installed' / triplet
    reference = args.reference_library.resolve()
    graphite = args.graphite_dir.resolve()
    fixture = repo / 'tools/native_skia_layer_shape_region_test.cpp'
    inputs = [Path(__file__).resolve(), fixture, repo / 'native_skia_text_darwin.cpp',
              reference, skia / 'lib/libskia.dylib', *repo.glob('native*.h'),
              *graphite.glob('*.dylib')]
    pins = {str(p): sha(p) for p in inputs}
    binary = output / 'clipped_shape_batch_test'
    command = ['clang++', '-std=c++20', '-O2', '-DVOX_TEST_CLIPPED_SHAPE_BATCH',
               '-x', 'objective-c++', '-I' + str(skia / 'include/skia'),
               '-I' + str(skia / 'include'), str(fixture), '-L' + str(skia / 'lib'), '-lskia']
    for framework in ['CoreFoundation', 'CoreGraphics', 'CoreText', 'Foundation', 'Metal']:
        command += ['-framework', framework]
    command += ['-Wl,-rpath,' + str(skia / 'lib'), '-Wl,-rpath,' + str(graphite), '-o', str(binary)]
    result = {'pins': pins, 'compile_command': command, 'trials': []}
    with (output / 'compile.log').open('x') as log:
        result['compile_exit'] = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT).returncode
    if result['compile_exit'] == 0:
        result['test_sha256'] = sha(binary)
        base = {k: v for k, v in os.environ.items() if not k.startswith(('VOX_', 'DYLD_'))}
        base.update(VOX_SKIA_REFERENCE_LIBRARY=str(reference), VOX_CLIPPED_SHAPE_BATCH_DIAGNOSTICS='1')
        for mode, flag, marker in [
            ('batch', None, 'VOX_CLIPPED_SHAPE_BATCH tiles='),
            ('before_gpu', 'VOX_TEST_CLIPPED_BATCH_FAIL_BEFORE_GPU', 'VOX_CLIPPED_BATCH_TEST_FAILURE before_gpu'),
            ('before_publish', 'VOX_TEST_CLIPPED_BATCH_FAIL_BEFORE_PUBLISH', 'VOX_CLIPPED_BATCH_TEST_FAILURE before_publish'),
        ]:
            env = dict(base)
            if flag:
                env[flag] = '1'
            with (output / (mode + '.log')).open('x') as log:
                code = subprocess.run([str(binary)], env=env, stdout=log, stderr=subprocess.STDOUT).returncode
            lines = (output / (mode + '.log')).read_text()
            row = {'mode': mode, 'test_exit': code, 'executed_paths': lines.count(marker),
                   'summary': lines.splitlines()[-1] if lines else ''}
            result['trials'].append(row)
            print(row, flush=True)
    result['changed_inputs'] = [p for p, digest in pins.items() if sha(Path(p)) != digest]
    passed = result['compile_exit'] == 0 and len(result['trials']) == 3 and not result['changed_inputs']
    passed = passed and all(r['test_exit'] == 0 and r['executed_paths'] > 0 for r in result['trials'])
    result['passed'] = passed
    (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
