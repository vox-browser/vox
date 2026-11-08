#!/usr/bin/env python3
"""Exercise transparent, video-only WebM through the browser playback bridge."""
import argparse
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    output = parser.parse_args().output.resolve()
    root = Path(__file__).resolve().parents[1]
    subprocess.run([sys.executable, str(root / 'tools/test_native_ffmpeg_alpha.py'),
                    '--output', str(output)], check=True)
    ffmpeg = shutil.which('ffmpeg')
    audible = output / 'audible.webm'
    subprocess.run([ffmpeg, '-v', 'error', '-y', '-f', 'lavfi', '-i',
                    'color=c=blue:s=16x16:d=1:r=2', '-f', 'lavfi', '-i',
                    'sine=frequency=440:duration=1', '-c:v', 'libvpx-vp9',
                    '-c:a', 'libopus', str(audible)], check=True)
    architecture = 'arm64' if platform.machine() in ('arm64', 'aarch64') else 'x64'
    triplet = os.environ.get('LADYBIRD_VCPKG_TRIPLET', architecture + '-osx-dynamic')
    upstream = Path(os.environ.get('LADYBIRD_SOURCE_DIR', root.parent / '3rd/ladybird'))
    libraries = upstream / 'Build/release/vcpkg_installed' / triplet
    binary = output / 'native-webm-playback'
    subprocess.run(['clang', '-O2', '-fblocks', '-DLADYBIRD_V_HAS_FFMPEG',
                    '-I' + str(libraries / 'include'),
                    str(root / 'tools/native_webm_playback_test.m'),
                    '-framework', 'Foundation', '-framework', 'CoreVideo',
                    '-framework', 'CoreMedia', '-Wl,-rpath,' + str(libraries / 'lib'),
                    '-o', str(binary)], check=True)
    for codec in ('libvpx', 'libvpx-vp9'):
        subprocess.run([str(binary), str(output / (codec + '.webm')),
                        str(output / (codec + '-0.rgba')),
                        str(output / (codec + '-1.rgba')), str(audible)], check=True)


if __name__ == '__main__':
    main()
