#!/usr/bin/env python3
"""Check integer image crops against frozen full-uBO Brave pixels.

Run through the 3 GiB memory guard. The selected canonical browser supplies
the native adapter; the V clip-selection test separately verifies its caller.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

from forum_news_pixels import REPO, VOX, executable_identity, write_json


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--vox', type=Path, default=VOX)
    parser.add_argument('--decoder', type=Path, default=Path('/opt/homebrew/lib/libwebpdecoder.dylib'))
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    source = REPO / 'tools/native_rect_image_clip_test.mm'
    image = REPO / 'Tests/Browser/Brave/resources/techcrunch-hero.webp'
    reference = REPO / 'Tests/Browser/Brave/expected/techcrunch-gradient-image.png'
    compiler = Path(shutil.which('clang++')).resolve()
    files = [source, Path(__file__).resolve(), REPO / 'native_graphite_bridge.h', image,
             reference, compiler, args.decoder.resolve()]
    bridge = args.vox.resolve().parent / 'libLadybirdVSkiaText.dylib'
    dependencies = subprocess.check_output(['otool', '-L', str(bridge)], text=True)
    if '@rpath/libskia.dylib ' in dependencies:
        commands = subprocess.check_output(['otool', '-l', str(bridge)], text=True).splitlines()
        candidates = [Path(commands[index + 2].strip().split(' (offset')[0][5:]) / 'libskia.dylib'
                      for index, line in enumerate(commands) if line.strip() == 'cmd LC_RPATH']
        skia = next((path.resolve() for path in candidates if path.is_file()), None)
        if skia is None:
            raise RuntimeError('Cannot pin the adapter\'s external Skia dependency')
        files.append(skia)
    environment = {k: v for k, v in os.environ.items()
                   if not k.startswith(('VOX_', 'LADYBIRD_', 'DYLD_', 'GC_'))}
    def identity():
        return dict(browser=executable_identity(args.vox.resolve()),
                    inputs={str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in files})
    before = identity()
    write_json(output / 'identity.json', before)
    result = dict(jobs=[])
    try:
        for name, flags in [('optimized', ['-O2']),
                            ('sanitized', ['-O1', '-g', '-fsanitize=address,undefined'])]:
            binary = output / name
            command = [str(compiler), '-std=c++20', *flags, str(source),
                       '-framework', 'Cocoa', '-o', str(binary)]
            row = dict(mode=name, command=command)
            result['jobs'].append(row)
            with (output / (name + '.log')).open('x') as log:
                row['compile_exit'] = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT).returncode
                if not row['compile_exit']:
                    row['binary_sha256'] = hashlib.sha256(binary.read_bytes()).hexdigest()
                    row['test_exit'] = subprocess.run([str(binary), str(image), str(reference),
                        str(bridge),
                        str(args.decoder.resolve()), str(args.vox.resolve().parent / 'libVoxGraphite.dylib')],
                        env=environment, stdout=log, stderr=subprocess.STDOUT).returncode
    finally:
        after = identity()
        write_json(output / 'identity-after.json', after)
        result['unchanged_inputs'] = before == after
        result['status'] = 'pass' if before == after and len(result['jobs']) == 2 and all(
            row.get('test_exit') == 0 for row in result['jobs']) else 'failure'
        write_json(output / 'summary.json', result)
    print(json.dumps(result), flush=True)
    return 0 if result['status'] == 'pass' else 1


if __name__ == '__main__':
    raise SystemExit(main())
