#!/usr/bin/env python3
"""Check static sRGB JPEG XL decoding with a sanitized driver."""
import argparse
import hashlib
import json
import os
import shutil
from pathlib import Path
import subprocess
import sys
import time

REPO = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path)
    parser.add_argument('--sdk-root', type=Path, default=REPO.parent /
                        '3rd/ladybird/Build/release/vcpkg_installed' /
                        ('arm64-osx-dynamic' if __import__('platform').machine() == 'arm64' else 'x64-osx-dynamic'))
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('These checks require macOS')
    output = (args.output_dir or REPO / 'Build/jpegxl-decoder' / str(time.time_ns())).resolve()
    output.mkdir(parents=True, exist_ok=False)
    sdk = args.sdk_root.resolve()
    libraries = [sdk / 'lib' / name for name in ['libjxl.dylib', 'libjxl_cms.dylib',
                 'libhwy.dylib', 'libbrotlidec.dylib', 'libbrotlicommon.dylib']]
    digest = lambda: {str(p.resolve()): hashlib.sha256(p.read_bytes()).hexdigest() for p in libraries}
    before = digest()
    (output / 'identity.json').write_text(json.dumps(before, indent=2) + '\n')
    environment = {k: v for k, v in os.environ.items()
                   if not k.startswith(('VOX_', 'LADYBIRD_', 'DYLD_', 'GC_'))}
    environment['ASAN_OPTIONS'] = 'detect_leaks=0'
    cargo = shutil.which('cargo') or '/opt/homebrew/opt/rustup/bin/cargo'
    environment['PATH'] = str(Path(cargo).parent) + os.pathsep + environment['PATH']
    rust_command = [cargo, 'build', '--release', '--locked', '--manifest-path',
                    str(REPO / 'native_jpegxl_rust/Cargo.toml'), '--target-dir', str(output / 'rust')]
    helper = output / 'libVoxJPEGXL.dylib'
    executable = output / 'jpegxl-decoder'
    compile_command = ['clang++', '-std=c++20', '-O1', '-g', '-fsanitize=address,undefined',
                       '-fno-omit-frame-pointer', '-I' + str(sdk / 'include'), str(REPO / 'tools/native_jpegxl_test.cpp'),
                       '-L' + str(sdk / 'lib'), '-ljxl', '-Wl,-rpath,' + str(sdk / 'lib'),
                       '-o', str(executable)]
    for phase, command, limit in [('rust', rust_command, '12'), ('compile', compile_command, '12'),
                                   ('run', [str(executable)], '3')]:
        prefix = output / phase
        guard = [sys.executable, str(REPO / 'tools/run_memory_bounded.py'),
                 '--lock', str(prefix) + '.lock', '--report', str(prefix) + '.guard.json',
                 '--limit-gib', limit, '--timeout', '180', '--', *command]
        Path(str(prefix) + '.command.json').write_text(json.dumps(guard, indent=2) + '\n')
        with Path(str(prefix) + '.log').open('x') as log:
            code = subprocess.run(guard, cwd=REPO, env=environment,
                                  stdout=log, stderr=subprocess.STDOUT).returncode
        if phase == 'rust' and code == 0:
            shutil.copy2(output / 'rust/release/libvox_jpegxl.dylib', helper)
            (output / 'helper-identity.json').write_text(json.dumps({str(helper):
                hashlib.sha256(helper.read_bytes()).hexdigest()}, indent=2) + '\n')
        if digest() != before:
            raise RuntimeError('JPEG XL dependency changed during the check')
        if code:
            print(f'JPEG XL {phase} failed; evidence: {output}')
            return code
    print(f'JPEG XL checks passed; evidence: {output}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
