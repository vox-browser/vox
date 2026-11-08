#!/usr/bin/env python3
"""Check exact full-tile and clipped root image replay on macOS.

Compile under the 12 GiB memory guard; run each check under 3 GiB.
The selected completed browser supplies the GPU backend, without copying it.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--sanitize', action='store_true')
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('Requires macOS and the completed native renderer')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    upstream = Path(os.environ.get('LADYBIRD_SOURCE_DIR', ROOT.parent / '3rd/ladybird'))
    triplet = os.environ.get('LADYBIRD_VCPKG_TRIPLET',
                             'arm64-osx-dynamic' if os.uname().machine == 'arm64' else 'x64-osx-dynamic')
    skia = upstream / 'Build/release/vcpkg_installed' / triplet
    backend = ROOT / 'Build/v/Vox.app/Contents/MacOS'
    sources = [ROOT / 'native_skia_text_darwin.cpp', *ROOT.glob('native*.h'),
               ROOT / 'tools/native_skia_root_image_region_test.cpp',
               ROOT / 'tools/native_skia_image_root_rows_test.cpp']
    before = {str(p.resolve()): sha(p) for p in sources}
    records = []

    def run(name, command, limit):
        guarded = [sys.executable, str(ROOT / 'tools/run_memory_bounded.py'),
                   '--lock', str(output / (name + '.lock')),
                   '--report', str(output / (name + '-guard.json')),
                   '--limit-gib', str(limit), '--', *command]
        with (output / (name + '.log')).open('w') as log:
            result = subprocess.run(guarded, stdout=log, stderr=subprocess.STDOUT,
                                    env=dict(os.environ, ASAN_OPTIONS='detect_leaks=0',
                                             UBSAN_OPTIONS='halt_on_error=1'))
        records.append(dict(name=name, command=guarded, exit=result.returncode))
        (output / 'commands.json').write_text(json.dumps(records, indent=2) + '\n')
        result.check_returncode()

    from browser_bundle_lease import publication_lease
    with publication_lease(ROOT, shared=True):
        libraries = {str(p): sha(p) for p in backend.glob('*.dylib')}
        for name in ['native_skia_root_image_region_test', 'native_skia_image_root_rows_test']:
            binary, deps = output / name, output / (name + '.d')
            flags = ['-O1', '-g', '-fsanitize=address,undefined', '-fno-omit-frame-pointer'] \
                if args.sanitize else ['-O2']
            command = ['clang++', '-std=c++20', *flags, '-fno-rtti', '-x', 'objective-c++',
                       '-I' + str(skia / 'include/skia'), '-I' + str(skia / 'include'),
                       str(ROOT / 'tools' / (name + '.cpp')), '-L' + str(skia / 'lib'),
                       '-lskia', '-Wl,-rpath,' + str(skia / 'lib'), '-Wl,-rpath,' + str(backend),
                       '-MMD', '-MF', str(deps), '-o', str(binary)]
            for framework in ['CoreFoundation', 'CoreGraphics', 'CoreText', 'Foundation', 'Metal', 'IOSurface']:
                command += ['-framework', framework]
            run(name + '-compile', command, 12)
            paths = [Path(p).resolve() for p in shlex.split(deps.read_text().replace('\\\n', ' ').split(':', 1)[1])]
            pinned = {str(p): before[str(p)] for p in paths if str(p) in before}
            assert pinned == {p: sha(Path(p)) for p in pinned}, 'Compiled source changed during checks'
            run(name + '-runtime', [str(binary)], 3)
            print((output / (name + '-runtime.log')).read_text().splitlines()[0], flush=True)
        assert libraries == {str(p): sha(p) for p in backend.glob('*.dylib')}, 'Backend changed'
        (output / 'receipt.json').write_text(json.dumps(dict(passed=True, sanitized=args.sanitize,
            libraries=libraries, sources=before, commands=records), indent=2) + '\n')


if __name__ == '__main__':
    main()
