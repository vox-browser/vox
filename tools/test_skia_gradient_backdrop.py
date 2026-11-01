#!/usr/bin/env python3
"""Run real GPU gradient-backdrop and native tile checks under AddressSanitizer."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time

REPO = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path)
    parser.add_argument('--native-dir', type=Path,
                        default=REPO / 'Build/v/Vox.app/Contents/MacOS')
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('These checks require macOS')
    output = (args.output_dir or REPO / 'Build/skia-gradient-backdrop' / str(time.time_ns())).resolve()
    output.mkdir(parents=True, exist_ok=False)
    native = output / 'native'
    native.mkdir()
    modules = [args.native_dir / name for name in
               ['libVoxGraphite.dylib', 'libVoxGraphiteDawn.dylib']]
    identity = lambda: {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in modules}
    before = identity()
    for module in modules:
        shutil.copyfile(module, native / module.name)
        assert before[str(module)] == hashlib.sha256((native / module.name).read_bytes()).hexdigest()
    assert before == identity()
    (output / 'module-identity.json').write_text(json.dumps(before, indent=2))
    upstream = Path(os.environ.get('LADYBIRD_SOURCE_DIR', REPO.parent / '3rd/ladybird'))
    triplet = os.environ.get('LADYBIRD_VCPKG_TRIPLET',
                            'arm64-osx-dynamic' if platform.machine() == 'arm64' else 'x64-osx-dynamic')
    skia = upstream / 'Build/release/vcpkg_installed' / triplet
    common = ['clang++', '-std=c++20', '-O1', '-g', '-fsanitize=address',
              '-fno-omit-frame-pointer', '-x', 'objective-c++',
              '-I' + str(skia / 'include/skia'), '-I' + str(skia / 'include'),
              '-L' + str(skia / 'lib'), '-lskia', '-Wl,-rpath,' + str(skia / 'lib'),
              '-Wl,-rpath,' + str(native)]
    for framework in ['CoreFoundation', 'CoreGraphics', 'CoreText', 'Foundation', 'Metal']:
        common += ['-framework', framework]
    for test in ['native_skia_gradient_backdrop_test', 'native_skia_gradient_tiles_test',
                 'native_skia_gradient_interpolation_test', 'native_skia_css_gradient_picture_test',
                 'native_skia_shared_layer_test', 'native_picture_image_transport_test',
                 'native_chromium_image_resize_test',
                 'native_skia_profiled_image_picture_test', 'native_graphite_mipped_image_test']:
        executable = output / test
        compile_command = common + [str(REPO / 'tools' / (test + '.cpp')), '-o', str(executable)]
        run_command = [str(executable)]
        if test == 'native_chromium_image_resize_test':
            run_command += [str(native / 'libVoxGraphite.dylib')]
        if test in ['native_skia_gradient_interpolation_test', 'native_graphite_mipped_image_test']:
            # Build the independent reference with the same pinned Chromium
            # Skia as the isolated GPU libraries, rather than LibWeb's ABI.
            source = REPO / 'Build/deps/skia-brave/source'
            compile_command = ['clang++', '-std=c++20', '-O1', '-g', '-fno-rtti',
                               '-fsanitize=address', '-fno-omit-frame-pointer',
                               '-I' + str(source), str(REPO / 'tools' / (test + '.cpp')),
                               str(source / 'out/Release/libskia.a'),
                               str(source / 'out/Release/libskcms.a'), '-o', str(executable)]
            for framework in ['Metal', 'CoreGraphics', 'Foundation', 'ImageIO', 'CoreText']:
                compile_command += ['-framework', framework]
            run_command += [str(native / module.name) for module in modules]
        for phase, command, limit in [
            ('compile', compile_command, '12'),
            ('runtime', run_command, '3'),
        ]:
            name = test + '-' + phase
            with (output / (name + '.log')).open('x') as log:
                code = subprocess.run([sys.executable, str(REPO / 'tools/run_memory_bounded.py'),
                                       '--lock', str(output / (name + '.lock')),
                                       '--report', str(output / (name + '-guard.json')),
                                       '--limit-gib', limit, '--'] + command,
                                      stdout=log, stderr=subprocess.STDOUT,
                                      env=dict(os.environ, ASAN_OPTIONS='detect_leaks=0')).returncode
            if code:
                print(f'{name} failed; evidence: {output}')
                return code
    assert before == identity()
    print(f'Native gradient checks passed; evidence: {output}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
