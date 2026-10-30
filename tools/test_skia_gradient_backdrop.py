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
    module = args.native_dir / 'libVoxGraphite.dylib'
    before = hashlib.sha256(module.read_bytes()).hexdigest()
    shutil.copyfile(module, native / module.name)
    assert before == hashlib.sha256(module.read_bytes()).hexdigest()
    assert before == hashlib.sha256((native / module.name).read_bytes()).hexdigest()
    (output / 'module-identity.json').write_text(json.dumps({'source': str(module), 'sha256': before}))
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
    for test in ['native_skia_gradient_backdrop_test', 'native_skia_gradient_tiles_test']:
        executable = output / test
        for phase, command, limit in [
            ('compile', common + [str(REPO / 'tools' / (test + '.cpp')), '-o', str(executable)], '12'),
            ('runtime', [str(executable)], '3'),
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
    print(f'Native gradient checks passed; evidence: {output}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
