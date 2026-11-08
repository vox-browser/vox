#!/usr/bin/env python3
"""Compare decoded WebM plane sampling with the checked-in Brave reference."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess

from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--graphite-library', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    library = args.graphite_library.resolve()
    movie = root / 'Tests/Browser/Brave/input/assets/transparent-odd.webm'
    reference = root / 'Tests/Browser/Brave/expected/transparent-webm-planes.png'
    inputs = [Path(__file__).resolve(), root / 'tools/native_webm_gpu_test.m',
              root / 'native/include/native_media_darwin.h', root / 'native/include/native_ffmpeg_playback_darwin.h',
              root / 'native/include/native_ffmpeg_darwin.h', library, movie, reference]

    def identity():
        return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}

    before = identity()
    architecture = 'arm64' if platform.machine() in ('arm64', 'aarch64') else 'x64'
    upstream = Path(os.environ.get('LADYBIRD_SOURCE_DIR', root.parent / '3rd/ladybird'))
    triplet = os.environ.get('LADYBIRD_VCPKG_TRIPLET', architecture + '-osx-dynamic')
    libraries = upstream / 'Build/release/vcpkg_installed' / triplet
    binary = output / 'native-webm-gpu'
    command = ['clang', '-O2', '-fblocks', '-DLADYBIRD_V_HAS_FFMPEG',
               '-I' + str(libraries / 'include'), str(root / 'tools/native_webm_gpu_test.m'),
               '-framework', 'Foundation', '-framework', 'CoreVideo', '-framework',
               'CoreMedia', '-Wl,-rpath,' + str(libraries / 'lib'), '-o', str(binary)]
    subprocess.run(command, check=True)
    raw = output / 'actual.bgra'
    subprocess.run([str(binary), str(movie), str(library), str(raw)], check=True)
    actual = Image.frombytes('RGBA', (800, 600), raw.read_bytes(), 'raw', 'BGRA')
    expected = Image.open(reference).convert('RGBA')
    comparisons = []
    for x, size in [(200, 34), (300, 65)]:
        mismatches = sum(actual.getpixel((xx, y)) != expected.getpixel((xx, y))
                         for y in range(8, 8 + size) for xx in range(x, x + size))
        comparisons.append(dict(x=x, y=8, width=size, height=size,
                                differing_pixels=mismatches))
    result = dict(inputs=before, inputs_unchanged=before == identity(),
                  scope='Normal source-over video crops; screen-blended crops require browser capture',
                  comparisons=comparisons)
    (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    assert result['inputs_unchanged'], 'Inputs changed during the test'
    assert all(row['differing_pixels'] == 0 for row in comparisons), result
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
