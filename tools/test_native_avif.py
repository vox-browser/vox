#!/usr/bin/env python3
"""Check the static AVIF decoder, original Slate images and failure controls."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

REPO = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--sanitize', action='store_true')
    parser.add_argument('--sdk-root', type=Path,
                        help='prefix holding include/avif and lib/libavif (default: pkg-config libavif)')
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('This native dependency audit currently requires macOS')
    output = (args.output or REPO / 'Build/native-avif' / str(time.time_ns())).resolve()
    output.mkdir(parents=True, exist_ok=False)
    # Homebrew's libavif (`brew install libavif`) unless an explicit prefix is given.
    if args.sdk_root:
        include, lib = args.sdk_root.resolve() / 'include', args.sdk_root.resolve() / 'lib'
    else:
        include, lib = (Path(subprocess.check_output(
            ['pkg-config', '--variable=' + name, 'libavif'], text=True).strip()).resolve()
            for name in ('includedir', 'libdir'))
    resources = REPO / 'Tests/Browser/Brave/resources/avif'
    # Pin libavif and its non-system codec libraries (dav1d, aom, ...).
    dependencies = set()
    pending = [lib / 'libavif.dylib']
    while pending:
        library = pending.pop().resolve()
        if library in dependencies:
            continue
        dependencies.add(library)
        lines = subprocess.check_output(['otool', '-L', str(library)], text=True).splitlines()[1:]
        for line in lines:
            name = line.strip().split(' (', 1)[0]
            path = library.parent / Path(name).name if name.startswith('@rpath/') else Path(name)
            if path.is_file() and not str(path).startswith(('/usr/lib/', '/System/')):
                pending.append(path)
    paths = [REPO / 'native_avif.c', REPO / 'native/include/native_avif.h',
             REPO / 'tools/native_avif_test.cpp', REPO / 'tools/build_native_avif.py',
             REPO / 'tools/native_avif_v_check.v', *sorted((REPO / 'yuv').glob('*.v')),
             Path(__file__).resolve(), include / 'avif/avif.h',
             *sorted(resources.iterdir()), *sorted(dependencies)]
    pins = lambda: {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}
    before = pins()
    (output / 'identities.json').write_text(json.dumps(before, indent=2) + '\n')
    helper = output / 'libVoxAVIF.dylib'
    executable = output / 'native_avif_test'
    v_check = output / 'native_avif_v_check'
    flags = ['-O1', '-g', '-fsanitize=address,undefined', '-fno-omit-frame-pointer'] if args.sanitize else ['-O2']
    build = [sys.executable, str(REPO / 'tools/build_native_avif.py'), '--output', str(helper)]
    if args.sdk_root:
        build += ['--sdk-root', str(args.sdk_root.resolve())]
    if args.sanitize:
        build.append('--sanitize')
    commands = [('helper', build, 12),
        ('compile', ['clang++', '-std=c++20', *flags, str(REPO / 'tools/native_avif_test.cpp'), '-o', str(executable)], 12),
        ('runtime', [str(executable), str(resources)], 3),
        # The browser converts opaque 8-bit images in V; its bytes must match
        # Brave's. The checker loads the helper beside it.
        ('v-compile', [os.environ.get('V_BIN', 'v'), '-b', 'c', '-memory-limit', '10G',
                       '-path', f'{REPO}|@vlib|@vmodules', '-o', str(v_check),
                       str(REPO / 'tools/native_avif_v_check.v')], 12),
        ('v-runtime', [str(v_check), str(resources)], 3)]
    results = []
    environment = dict(os.environ, ASAN_OPTIONS='detect_leaks=0')
    for phase, command, limit in commands:
        guard = [sys.executable, str(REPO / 'tools/run_memory_bounded.py'), '--limit-gib', str(limit),
                 '--lock', str(output / (phase + '.lock')), '--report', str(output / (phase + '.guard.json')), '--', *command]
        (output / (phase + '.command.json')).write_text(json.dumps(guard, indent=2) + '\n')
        with (output / (phase + '.log')).open('x') as log:
            code = subprocess.run(guard, cwd=REPO, env=environment, stdout=log, stderr=subprocess.STDOUT).returncode
        results.append(dict(phase=phase, exit=code))
        if code:
            break
    after = pins()
    (output / 'identities-after.json').write_text(json.dumps(after, indent=2) + '\n')
    summary = dict(status='pass' if before == after and all(r['exit'] == 0 for r in results) else 'failure',
                   sanitized=args.sanitize, unchanged_inputs=before == after, results=results,
                   helper_sha256=hashlib.sha256(helper.read_bytes()).hexdigest() if helper.exists() else None)
    (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(dict(**summary, artifacts=str(output))))
    return 0 if summary['status'] == 'pass' else 1


if __name__ == '__main__':
    sys.exit(main())
