#!/usr/bin/env python3
"""Check scrolled image tile coordinates against complete GPU tiles on macOS."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import time

REPO = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path)
    parser.add_argument('--native-dir', type=Path,
                        default=REPO / 'Build/v/Vox.app/Contents/MacOS')
    parser.add_argument('--negative-control', action='store_true',
                        help='Also require the preceding scroll formula to fail')
    parser.add_argument('--bridge-library', type=Path,
                        help='Also exercise a completed browser native-text library through its public API')
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('These checks require macOS')
    output = (args.output_dir or REPO / 'Build/scrolled-image-grid' / str(time.time_ns())).resolve()
    output.mkdir(parents=True, exist_ok=False)
    sources = [REPO / 'native_skia_text_darwin.cpp',
               REPO / 'tools/native_skia_scrolled_image_grid_test.cpp',
               REPO / 'tools/native_skia_image_root_rows_test.cpp']
    sources += sorted(REPO.glob('native_*.h'))
    source_identity = lambda: {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
                               for path in sources}
    source_before = source_identity()
    (output / 'source-identity-before.json').write_text(json.dumps(source_before, indent=2))
    native = output / 'native'
    native.mkdir()
    modules = [args.native_dir / name for name in ['libVoxGraphite.dylib', 'libVoxGraphiteDawn.dylib']]
    identity = lambda: {str(path.resolve()): hashlib.sha256(path.read_bytes()).hexdigest()
                        for path in modules}
    before = identity()
    for module in modules:
        shutil.copyfile(module, native / module.name)
        assert hashlib.sha256((native / module.name).read_bytes()).hexdigest() == before[str(module.resolve())]
    assert before == identity()
    (output / 'module-identity.json').write_text(json.dumps(before, indent=2))
    upstream = Path(os.environ.get('LADYBIRD_SOURCE_DIR', REPO.parent / '3rd/ladybird'))
    triplet = os.environ.get('LADYBIRD_VCPKG_TRIPLET',
                            'arm64-osx-dynamic' if platform.machine() == 'arm64' else 'x64-osx-dynamic')
    skia = upstream / 'Build/release/vcpkg_installed' / triplet
    common = ['clang++', '-std=c++20', '-O1', '-g', '-fsanitize=address,undefined',
              '-fno-omit-frame-pointer', '-x', 'objective-c++', '-I' + str(REPO),
              '-I' + str(skia / 'include/skia'), '-I' + str(skia / 'include'),
              '-L' + str(skia / 'lib'), '-lskia', '-Wl,-rpath,' + str(skia / 'lib'),
              '-Wl,-rpath,' + str(native)]
    for framework in ['CoreFoundation', 'CoreGraphics', 'CoreText', 'Foundation', 'Metal']:
        common += ['-framework', framework]

    def guarded(name, command, limit, expected=0):
        (output / (name + '-command.json')).write_text(json.dumps(command, indent=2))
        if name.endswith('runtime'):
            binary = Path(command[0])
            (output / (name + '-identity.json')).write_text(json.dumps({str(binary):
                hashlib.sha256(binary.read_bytes()).hexdigest()}, indent=2))
        with (output / (name + '.log')).open('x') as log:
            code = subprocess.run([sys.executable, str(REPO / 'tools/run_memory_bounded.py'),
                                   '--lock', str(output / (name + '.lock')),
                                   '--report', str(output / (name + '-guard.json')),
                                   '--limit-gib', str(limit), '--'] + command,
                                  stdout=log, stderr=subprocess.STDOUT,
                                  env=dict(os.environ, ASAN_OPTIONS='detect_leaks=0',
                                           UBSAN_OPTIONS='halt_on_error=1')).returncode
        if code != expected:
            raise RuntimeError(f'{name}: expected exit {expected}, got {code}; evidence: {output}')

    for test in ['native_skia_scrolled_image_grid_test', 'native_skia_image_root_rows_test']:
        binary = output / test
        guarded(test + '-compile', common + [str(REPO / 'tools' / (test + '.cpp')),
                                             '-o', str(binary)], 12)
        guarded(test + '-runtime', [str(binary)], 3)
        if args.bridge_library and test == 'native_skia_scrolled_image_grid_test':
            library = args.bridge_library.resolve()
            digest = hashlib.sha256(library.read_bytes()).hexdigest()
            (output / 'bridge-identity.json').write_text(json.dumps({str(library): digest}, indent=2))
            guarded('bridge-runtime', [str(binary), str(library)], 3)
            assert digest == hashlib.sha256(library.read_bytes()).hexdigest()
    if args.negative_control:
        source = (REPO / 'native_skia_text_darwin.cpp').read_text()
        new = '+ s_root_raster_scroll_y - (s_raster_layer_is_root ? 0 : s_raster_origin_y)) * scale);'
        old = '+ (s_raster_layer_is_root ? s_root_raster_scroll_y : -s_raster_origin_y)) * scale);'
        assert source.count(new) == 1
        negative = output / 'native-text-negative.cpp'
        negative.write_text(source.replace(new, old))
        binary = output / 'negative-control'
        guarded('negative-compile', common + ['-DVOX_SKIA_TEXT_UNDER_TEST="' + str(negative) + '"',
                str(REPO / 'tools/native_skia_scrolled_image_grid_test.cpp'), '-o', str(binary)], 12)
        guarded('negative-runtime', [str(binary)], 3, expected=1)
        log = (output / 'negative-runtime.log').read_text()
        result = re.search(r'Scrolled image grids: (\d+) scenes, (\d+) rejected grids, (\d+) differing pixels', log)
        assert result and tuple(map(int, result.groups()[:2])) == (64, 32)
        assert int(result[3]) > 0
    assert before == identity()
    source_after = source_identity()
    (output / 'source-identity-after.json').write_text(json.dumps(source_after, indent=2))
    assert source_before == source_after, 'Native inputs changed during validation'
    (output / 'status.json').write_text(json.dumps({'passed': True,
        'negative_control': args.negative_control}, indent=2))
    print(f'Scrolled image grids passed; evidence: {output}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
