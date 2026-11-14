#!/usr/bin/env python3
"""Build the small AVIF decoder against the platform's existing libavif."""
import argparse
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile

REPO = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--sdk-root', type=Path)
    parser.add_argument('--sanitize', action='store_true')
    args = parser.parse_args()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    if sys.platform == 'darwin':
        # Homebrew's libavif (`brew install libavif`), or an
        # explicit prefix holding include/avif and lib/libavif.
        sdk = args.sdk_root.resolve() if args.sdk_root else Path(subprocess.check_output(
            ['sh', str(REPO / 'tools/run_v_tool.sh'), 'macos_dependency_prefix', 'libavif'],
            text=True).strip())
        flags = ['-I' + str(sdk / 'include'), '-L' + str(sdk / 'lib'), '-lavif',
                 '-Wl,-rpath,' + str(sdk / 'lib')]
        flags += ['-dynamiclib', '-Wl,-install_name,@rpath/libVoxAVIF.dylib']
    elif sys.platform == 'linux':
        flags = shlex.split(subprocess.check_output(
            ['pkg-config', '--cflags', '--libs', 'libavif'], text=True))
        flags += ['-shared', '-Wl,-soname,libVoxAVIF.so']
    else:
        parser.error('The native AVIF helper requires macOS or Linux')
    optimize = ['-O1', '-g', '-fsanitize=address,undefined', '-fno-omit-frame-pointer'] if args.sanitize else ['-O2']
    with tempfile.TemporaryDirectory(prefix='.avif-', dir=output.parent) as temporary:
        staged = Path(temporary) / output.name
        subprocess.run([os.environ.get('CC', 'clang'), '-std=c11', '-fPIC',
                        '-fvisibility=hidden', *optimize, str(REPO / 'native_avif.c'),
                        *flags, '-o', str(staged)], check=True)
        staged.replace(output)
    print(output)


if __name__ == '__main__':
    main()
