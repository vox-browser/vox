#!/usr/bin/env python3
"""Check SVG raster clipping and publication with sanitizers."""
import argparse
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
    output = (args.output_dir or REPO / 'Build/skia-svg-clip' / str(time.time_ns())).resolve()
    output.mkdir(parents=True, exist_ok=False)
    upstream = Path(os.environ.get('LADYBIRD_SOURCE_DIR', REPO.parent / '3rd/ladybird'))
    triplet = os.environ.get('LADYBIRD_VCPKG_TRIPLET',
                            'arm64-osx-dynamic' if platform.machine() == 'arm64' else 'x64-osx-dynamic')
    skia = upstream / 'Build/release/vcpkg_installed' / triplet
    environment = {k: v for k, v in os.environ.items()
                   if not k.startswith(('VOX_', 'LADYBIRD_', 'DYLD_', 'GC_'))}
    environment['ASAN_OPTIONS'] = 'detect_leaks=0'
    for name, source in [('svg-clip', 'native_skia_svg_clip_test.cpp')]:
        executable = output / name
        command = ['clang++', '-std=c++20', '-O1', '-g', '-fsanitize=address,undefined',
                   '-fno-omit-frame-pointer']
        if name == 'svg-clip':
            command += ['-x', 'objective-c++', '-I' + str(skia / 'include/skia'),
                        '-I' + str(skia / 'include'), '-L' + str(skia / 'lib'), '-lskia',
                        '-Wl,-rpath,' + str(skia / 'lib'),
                        '-Wl,-rpath,' + str(args.graphite_dir.resolve())]
            for framework in ['CoreFoundation', 'CoreGraphics', 'CoreText', 'Foundation', 'Metal']:
                command += ['-framework', framework]
        command += [str(REPO / 'tools' / source), '-o', str(executable)]
        for phase, cmd, limit in [('compile', command, '12'), ('run', [str(executable)], '3')]:
            prefix = output / (name + '-' + phase)
            guard = [sys.executable, str(REPO / 'tools/run_memory_bounded.py'),
                     '--lock', str(prefix) + '.lock', '--report', str(prefix) + '.guard.json',
                     '--limit-gib', limit, '--timeout', '300', '--', *cmd]
            Path(str(prefix) + '.command.json').write_text(json.dumps(guard, indent=2) + '\n')
            with Path(str(prefix) + '.log').open('x') as log:
                code = subprocess.run(guard, cwd=REPO, env=environment,
                                      stdout=log, stderr=subprocess.STDOUT).returncode
            if code:
                print(f'{name} {phase} failed; evidence: {output}')
                return code
    print(f'SVG raster clip checks passed; evidence: {output}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
