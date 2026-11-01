#!/usr/bin/env python3
"""Compare the screen compositor with independent Skia GPU pictures."""

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
    parser.add_argument('--skia-root', type=Path,
                        default=repo / 'Build/deps/skia-brave/source')
    parser.add_argument('--dawn-library', type=Path,
                        default=repo / 'Build/v/Vox.app/Contents/MacOS/libVoxGraphiteDawn.dylib')
    args = parser.parse_args()
    output = args.output or Path(tempfile.mkdtemp(prefix='screen-blend-', dir=repo / 'Build'))
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    skia, dawn = args.skia_root.resolve(), args.dawn_library.resolve()
    sources = [repo / name for name in ['native_chromium_screen_blend.h',
               'native_graphite_bridge.h', 'native_picture_image_transport.h',
               'tools/native_chromium_screen_blend_test.cpp']]
    sources += [skia / 'out/Release/libskia.a', skia / 'out/Release/libskcms.a', dawn]
    before = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}
    binary = output / 'screen-blend-test'
    compile_command = ['clang++', '-std=c++20', '-O1', '-g', '-fno-rtti',
                       '-fsanitize=address,undefined', '-fno-omit-frame-pointer', '-I' + str(skia),
                       str(sources[3]), str(sources[4]), str(sources[5]), '-o', str(binary)]
    for framework in ['Metal', 'CoreGraphics', 'Foundation', 'ImageIO', 'CoreText']:
        compile_command += ['-framework', framework]
    steps = []
    for name, command, limit in [('build', compile_command, 12), ('run', [str(binary), str(dawn)], 3)]:
        guarded = ['python3', str(repo / 'tools/run_memory_bounded.py'), '--limit-gib', str(limit),
                   '--lock', str(output / (name + '.lock')),
                   '--report', str(output / (name + '.json')), '--', *command]
        with (output / (name + '.log')).open('x') as log:
            code = subprocess.run(guarded, cwd=repo, stdout=log, stderr=subprocess.STDOUT).returncode
        steps.append(dict(name=name, exit_code=code))
        print((output / (name + '.log')).read_text(), end='')
        if code:
            break
    after = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}
    stable = before == after
    with (output / 'status.json').open('x') as status:
        json.dump(dict(steps=steps, sources=before, sources_unchanged=stable), status, indent=2)
    print('Artifacts:', output)
    return steps[-1]['exit_code'] or (0 if stable else 1)


if __name__ == '__main__':
    raise SystemExit(main())
