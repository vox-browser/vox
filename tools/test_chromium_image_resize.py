#!/usr/bin/env python3
"""Check Chromium-pinned resize hashes, profile/alpha handling and descriptor bounds."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile


def main():
    repo = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--library', type=Path,
                        default=repo / 'Build/v/Vox.app/Contents/MacOS/libVoxGraphite.dylib')
    args = parser.parse_args()
    output = args.output or Path(tempfile.mkdtemp(prefix='image-resize-', dir=repo / 'Build'))
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    test_source = repo / 'tools/native_chromium_image_resize_test.cpp'
    sources = [repo / name for name in ['native_graphite_bridge.h', 'native_graphite_darwin.mm',
               'native_image_color_profile.h', 'native_skia_image_color_space.h']]
    library = args.library.resolve()
    sources += [test_source, library]
    identity = lambda: {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}
    before = identity()
    binary = output / 'image-resize-test'
    commands = [
        ('build', ['clang++', '-std=c++20', '-O1', '-g', '-fsanitize=address,undefined',
                   '-fno-omit-frame-pointer', '-Wall', '-Wextra', '-Werror',
                   str(test_source), '-o', str(binary)], 12),
        ('run', [str(binary), str(library)], 3),
    ]
    steps = []
    for name, command, limit in commands:
        guarded = ['python3', str(repo / 'tools/run_memory_bounded.py'), '--limit-gib', str(limit),
                   '--lock', str(output / (name + '.lock')),
                   '--report', str(output / (name + '.json')), '--', *command]
        with (output / (name + '.log')).open('x') as log:
            code = subprocess.run(guarded, cwd=repo, stdout=log, stderr=subprocess.STDOUT).returncode
        steps.append(dict(name=name, exit_code=code))
        print((output / (name + '.log')).read_text(), end='')
        if code:
            break
    after = identity()
    stable = before == after
    with (output / 'status.json').open('x') as status:
        json.dump(dict(steps=steps, sources=before, sources_unchanged=stable), status, indent=2)
    print('Artifacts:', output)
    return steps[-1]['exit_code'] or (0 if stable else 1)


if __name__ == '__main__':
    raise SystemExit(main())
