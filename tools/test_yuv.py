#!/usr/bin/env python3
"""Compile and execute the browser's V YUV bridge through its native FFmpeg caller."""
import argparse
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('The FFmpeg bridge check requires macOS; V module tests are portable')
    root = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    compiler = os.environ.get('V_BIN') or shutil.which('v') or str(Path.home() / 'code/v/v')
    arch = 'arm64' if platform.machine() in ('arm64', 'aarch64') else 'x64'
    triplet = os.environ.get('LADYBIRD_VCPKG_TRIPLET', arch + '-osx-dynamic')
    upstream = Path(os.environ.get('LADYBIRD_SOURCE_DIR', root.parent / '3rd/ladybird'))
    sdk = upstream / 'Build/release/vcpkg_installed' / triplet
    library = output / 'libVoxYUV.dylib'
    executable = output / 'native-yuv'
    flags = ['-fblocks', '-DLADYBIRD_V_HAS_FFMPEG', '-DLADYBIRD_V_HAS_V_YUV',
             '-I' + str(sdk / 'include')]
    commands = [
        ('compile-v', '12', [compiler, '-memory-limit', '10G', '-b', 'c', '-cc', 'clang',
                            '-gc', 'none', '-shared', '-o', str(library),
                            str(root / 'media/yuv_bridge.v')]),
        ('name-library', '12', ['install_name_tool', '-id', '@rpath/libVoxYUV.dylib', str(library)]),
        # Check the actual exported prototype against the native declaration.
        ('check-prototypes', '12', ['clang', *flags, '-fsyntax-only', str(output / 'abi.m')]),
        ('compile-native', '12', ['clang', '-O1', '-g', '-fsanitize=address,undefined',
                                 *flags, str(root / 'tools/native_yuv_test.m'), str(library),
                                 '-framework', 'Foundation', '-Wl,-rpath,' + str(output),
                                 '-o', str(executable)]),
        ('run', '3', [str(executable)]),
    ]
    environment = dict(os.environ, ASAN_OPTIONS='detect_leaks=0')
    for name, limit, command in commands:
        if name == 'check-prototypes':
            prototypes = [line for line in Path(str(library) + '.c').read_text().splitlines()
                          if ' bool vox_yuv_u8_to_rgba(' in line and line.endswith(';')]
            if len(prototypes) != 1:
                raise RuntimeError('Expected one exported V converter prototype')
            (output / 'abi.m').write_text(
                '#include "' + str(root / 'native/include/native_ffmpeg_darwin.h') + '"\n'
                'typedef uint8_t u8; typedef uint32_t u32;\n' + prototypes[0] + '\n')
        guard = [sys.executable, str(root / 'tools/run_memory_bounded.py'),
                 '--lock', str(output / (name + '.lock')),
                 '--report', str(output / (name + '.json')), '--limit-gib', limit,
                 '--timeout', '180', '--', *command]
        with (output / (name + '.log')).open('w') as log:
            result = subprocess.run(guard, cwd=root, env=environment, stdout=log, stderr=subprocess.STDOUT)
        if result.returncode:
            print((output / (name + '.log')).read_text())
            return result.returncode
    print((output / 'run.log').read_text())
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
