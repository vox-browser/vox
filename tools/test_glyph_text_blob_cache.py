#!/usr/bin/env python3
"""Check positioned-run ownership and exact Quartz replay on macOS.

Run through tools/run_memory_bounded.py. --reference-library compares the
candidate with a pinned production bridge instead of only uncached replay.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--reference-library', type=Path)
    parser.add_argument('--sanitize', action='store_true')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    skia = repo.parent / '3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic'
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    reference = args.reference_library.resolve() if args.reference_library else None
    digest = hashlib.sha256(reference.read_bytes()).hexdigest() if reference else None
    env = {k: v for k, v in os.environ.items() if not k.startswith('VOX_')}
    if reference:
        env['VOX_SKIA_REFERENCE_LIBRARY'] = str(reference)
    flags = ['clang++', '-std=c++20', '-O2', '-x', 'objective-c++',
             '-I' + str(skia / 'include/skia'), '-I' + str(skia / 'include')]
    if args.sanitize:
        flags += ['-fsanitize=address,undefined', '-fno-omit-frame-pointer']
    libraries = ['-L' + str(skia / 'lib'), '-lskia', '-Wl,-rpath,' + str(skia / 'lib')]
    for framework in ['CoreFoundation', 'CoreGraphics', 'CoreText', 'Foundation', 'Metal']:
        libraries += ['-framework', framework]
    attempts = []
    try:
        for name in ['native_glyph_text_blob_cache_test', 'native_skia_glyph_origin_test',
                     'native_skia_glyph_cache_test']:
            binary = output / name
            for command in [flags + [str(repo / 'tools' / (name + '.cpp'))]
                            + libraries + ['-o', str(binary)], [str(binary)]]:
                result = subprocess.run(command, env=env, capture_output=True, text=True)
                attempts.append(dict(command=command, exit_code=result.returncode,
                                     stdout=result.stdout, stderr=result.stderr))
                print(result.stdout, end='', flush=True)
                result.check_returncode()
        if reference and hashlib.sha256(reference.read_bytes()).hexdigest() != digest:
            raise RuntimeError('Reference library changed during checks')
    finally:
        (output / 'checks.json').write_text(json.dumps(dict(
            reference_library=str(reference) if reference else None,
            reference_sha256=digest, attempts=attempts), indent=2) + '\n')


if __name__ == '__main__':
    main()
