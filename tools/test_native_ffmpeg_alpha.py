#!/usr/bin/env python3
"""Check transparent VP8/VP9 frames against libvpx's decoded alpha planes."""
import argparse
from pathlib import Path
import shlex
import shutil
import subprocess


def ffmpeg_cflags():
    """Homebrew FFmpeg headers; the bridge dlopens its libraries at runtime."""
    return shlex.split(subprocess.check_output(
        ['pkg-config', '--cflags', 'libavformat', 'libavcodec', 'libavutil', 'libswscale'],
        text=True))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    ffmpeg = shutil.which('ffmpeg')
    if not ffmpeg:
        raise SystemExit('ffmpeg with libvpx is required')
    executable = output / 'native-ffmpeg-alpha'
    subprocess.run(['clang', '-O2', '-fblocks', '-DLADYBIRD_V_HAS_FFMPEG',
                    *ffmpeg_cflags(), str(root / 'tools/native_ffmpeg_alpha_test.m'),
                    '-framework', 'Foundation', '-o', str(executable)], check=True)
    raw = output / 'input.rgba'
    raw.write_bytes(bytes(channel for frame in range(2) for y in range(16)
                         for x in range(16) for channel in
                         (24, 48, 72, (0, 64, 128, 255)[(x // 4 + frame) % 4])))
    opaque = output / 'opaque.webm'
    subprocess.run([ffmpeg, '-v', 'error', '-y', '-f', 'lavfi', '-i',
                    'color=c=blue:s=16x16:d=1:r=2', '-c:v', 'libvpx-vp9',
                    '-pix_fmt', 'yuv420p', str(opaque)], check=True)
    for codec in ('libvpx', 'libvpx-vp9'):
        movie = output / (codec + '.webm')
        subprocess.run([ffmpeg, '-v', 'error', '-y', '-f', 'rawvideo',
                        '-pix_fmt', 'rgba', '-s', '16x16', '-r', '2', '-i', str(raw),
                        '-c:v', codec, '-pix_fmt', 'yuva420p', '-auto-alt-ref', '0',
                        str(movie)], check=True)
        decoded = output / (codec + '.rgba')
        subprocess.run([ffmpeg, '-v', 'error', '-y', '-c:v', codec, '-i', str(movie),
                        '-f', 'rawvideo', '-pix_fmt', 'rgba', str(decoded)], check=True)
        frames = decoded.read_bytes()
        if len(frames) != 2 * 16 * 16 * 4:
            raise RuntimeError('Unexpected reference frame count')
        references = [output / (codec + f'-{index}.rgba') for index in range(2)]
        for index, reference in enumerate(references):
            reference.write_bytes(frames[index * 1024:(index + 1) * 1024])
        subprocess.run([str(executable), str(movie), *map(str, references), str(opaque)], check=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
