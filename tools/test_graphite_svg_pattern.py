#!/usr/bin/env python3
"""Exercise repeated SVG picture shaders and unchanged failure paths."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

REPO = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path)
    parser.add_argument('--library', type=Path,
                        default=REPO / 'Build/v/Vox.app/Contents/MacOS/libVoxGraphite.dylib')
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('These checks require macOS')
    output = (args.output_dir or REPO / 'Build/graphite-svg-pattern' / str(time.time_ns())).resolve()
    output.mkdir(parents=True, exist_ok=False)
    library = args.library.resolve()
    digest = lambda: hashlib.sha256(library.read_bytes()).hexdigest()
    before = digest()
    (output / 'identity.json').write_text(json.dumps({str(library): before}, indent=2) + '\n')
    environment = {k: v for k, v in os.environ.items()
                   if not k.startswith(('VOX_', 'LADYBIRD_', 'DYLD_', 'GC_'))}
    environment['ASAN_OPTIONS'] = 'detect_leaks=0'
    executable = output / 'svg-pattern'
    compile_command = ['clang++', '-std=c++20', '-O1', '-g', '-fsanitize=address,undefined',
                       '-fno-omit-frame-pointer', str(REPO / 'tools/native_graphite_svg_pattern_test.cpp'),
                       '-o', str(executable)]
    for phase, command, limit in [('compile', compile_command, '12'),
                                   ('run', [str(executable), str(library)], '3')]:
        prefix = output / phase
        guard = [sys.executable, str(REPO / 'tools/run_memory_bounded.py'),
                 '--lock', str(prefix) + '.lock', '--report', str(prefix) + '.guard.json',
                 '--limit-gib', limit, '--timeout', '180', '--', *command]
        Path(str(prefix) + '.command.json').write_text(json.dumps(guard, indent=2) + '\n')
        with Path(str(prefix) + '.log').open('x') as log:
            code = subprocess.run(guard, cwd=REPO, env=environment,
                                  stdout=log, stderr=subprocess.STDOUT).returncode
        if digest() != before:
            raise RuntimeError('Native library changed during the check')
        if code:
            print(f'SVG pattern {phase} failed; evidence: {output}')
            return code
    print(f'SVG pattern checks passed; evidence: {output}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
