#!/usr/bin/env python3
"""Compare forced Metal multisampling with real disjoint Dawn path draws."""
import argparse
import hashlib
import json
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
    parser.add_argument('--graphite-dir', type=Path,
                        default=REPO / 'Build/v/Vox.app/Contents/MacOS')
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('These checks require macOS')
    output = (args.output_dir or REPO / 'Build/graphite-msaa-noop' / str(time.time_ns())).resolve()
    output.mkdir(parents=True, exist_ok=False)
    upstream = Path(os.environ.get('LADYBIRD_SOURCE_DIR', REPO.parent / '3rd/ladybird'))
    triplet = os.environ.get('LADYBIRD_VCPKG_TRIPLET',
                            'arm64-osx-dynamic' if platform.machine() == 'arm64' else 'x64-osx-dynamic')
    skia = upstream / 'Build/release/vcpkg_installed' / triplet
    libraries = [args.graphite_dir.resolve() / name for name in
                 ['libVoxGraphite.dylib', 'libVoxGraphiteDawn.dylib']]
    identity = lambda: {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in libraries}
    before = identity()
    (output / 'identity.json').write_text(json.dumps(before, indent=2) + '\n')
    environment = {key: value for key, value in os.environ.items()
                   if not key.startswith(('VOX_', 'LADYBIRD_', 'DYLD_', 'GC_'))}
    environment['ASAN_OPTIONS'] = 'detect_leaks=0'
    executable = output / 'msaa-noop'
    command = ['clang++', '-std=c++20', '-O1', '-g', '-fsanitize=address,undefined',
               '-fno-omit-frame-pointer', '-I' + str(skia / 'include/skia'),
               '-I' + str(skia / 'include'), '-L' + str(skia / 'lib'), '-lskia',
               '-Wl,-rpath,' + str(skia / 'lib'),
               str(REPO / 'tools/native_graphite_msaa_noop_test.cpp'), '-o', str(executable)]
    for framework in ['CoreFoundation', 'CoreGraphics', 'CoreText', 'Foundation', 'Metal']:
        command += ['-framework', framework]
    for phase, cmd, limit in [('compile', command, '12'),
                              ('run', [str(executable), *map(str, libraries)], '3')]:
        prefix = output / phase
        guard = [sys.executable, str(REPO / 'tools/run_memory_bounded.py'),
                 '--lock', str(prefix) + '.lock', '--report', str(prefix) + '.guard.json',
                 '--limit-gib', limit, '--timeout', '180', '--', *cmd]
        Path(str(prefix) + '.command.json').write_text(json.dumps(guard, indent=2) + '\n')
        with Path(str(prefix) + '.log').open('x') as log:
            code = subprocess.run(guard, cwd=REPO, env=environment,
                                  stdout=log, stderr=subprocess.STDOUT).returncode
        if identity() != before:
            raise RuntimeError('Native library changed during the check')
        if code:
            print(f'MSAA {phase} failed; evidence: {output}')
            return code
    print(f'Forced MSAA checks passed; evidence: {output}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
