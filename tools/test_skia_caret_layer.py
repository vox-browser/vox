#!/usr/bin/env python3
"""Compile and execute compositor caret checks with AddressSanitizer."""
import argparse
import os
from pathlib import Path
import platform
import subprocess
import sys
import time

REPO = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path)
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('These checks require macOS')
    output = (args.output_dir or REPO / 'Build/skia-caret-layer' / str(time.time_ns())).resolve()
    output.mkdir(parents=True, exist_ok=False)
    upstream = Path(os.environ.get('LADYBIRD_SOURCE_DIR', REPO.parent / '3rd/ladybird'))
    triplet = os.environ.get('LADYBIRD_VCPKG_TRIPLET',
                            'arm64-osx-dynamic' if platform.machine() == 'arm64' else 'x64-osx-dynamic')
    skia = upstream / 'Build/release/vcpkg_installed' / triplet
    executable = output / 'caret-layer'
    command = ['clang++', '-std=c++20', '-O1', '-g', '-fsanitize=address,undefined',
               '-fno-omit-frame-pointer', '-x', 'objective-c++',
               '-I' + str(skia / 'include/skia'), '-I' + str(skia / 'include'),
               str(REPO / 'tools/native_skia_caret_layer_test.cpp'),
               '-L' + str(skia / 'lib'), '-lskia', '-Wl,-rpath,' + str(skia / 'lib'),
               '-Wl,-rpath,' + str(REPO / 'Build/v/Vox.app/Contents/MacOS')]
    for framework in ['CoreFoundation', 'CoreGraphics', 'CoreText', 'Foundation', 'Metal']:
        command += ['-framework', framework]
    command += ['-o', str(executable)]
    for name, args, limit in [('compile', command, '12'), ('runtime', [str(executable)], '3')]:
        with (output / (name + '.log')).open('x') as log:
            code = subprocess.run([sys.executable, str(REPO / 'tools/run_memory_bounded.py'),
                                   '--lock', str(output / (name + '.lock')),
                                   '--report', str(output / (name + '.guard.json')),
                                   '--limit-gib', limit, '--', *args], cwd=REPO,
                                  stdout=log, stderr=subprocess.STDOUT,
                                  env=dict(os.environ, ASAN_OPTIONS='detect_leaks=0')).returncode
        if code:
            print(f'{name} failed; evidence: {output}')
            return code
    print(f'Native compositor caret checks passed; evidence: {output}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
