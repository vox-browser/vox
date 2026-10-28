#!/usr/bin/env python3
"""Exercise the macOS playback bridge with deterministic MP4 and HTTP HLS."""
import argparse
import functools
import http.server
from pathlib import Path
import shutil
import subprocess
import threading


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    root = Path(__file__).resolve().parents[1]
    ffmpeg = shutil.which('ffmpeg')
    if not ffmpeg:
        raise SystemExit('ffmpeg is required to generate the playback fixtures')
    subprocess.run([ffmpeg, '-v', 'error', '-y', '-f', 'lavfi', '-i',
                    'testsrc2=size=160x90:rate=24:duration=4', '-f', 'lavfi', '-i',
                    'sine=frequency=440:duration=4', '-c:v', 'libx264', '-pix_fmt',
                    'yuv420p', '-g', '24', '-c:a', 'aac', '-movflags', '+faststart',
                    str(output / 'movie.mp4')], check=True)
    subprocess.run([ffmpeg, '-v', 'error', '-y', '-i', str(output / 'movie.mp4'),
                    '-c', 'copy', '-hls_time', '1', '-hls_list_size', '0',
                    str(output / 'movie.m3u8')], check=True)
    binary = output / 'native-media-test'
    command = ['clang', '-fblocks', '-Wno-deprecated-declarations', '-framework',
               'Foundation', '-framework', 'AVFoundation', '-framework', 'CoreVideo',
               '-framework', 'CoreMedia', str(root / 'tools/native_media_playback_test.m'),
               '-o', str(binary)]
    subprocess.run(command, check=True)
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(output))
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        subprocess.run([str(binary), (output / 'movie.mp4').as_uri(),
                        f'http://127.0.0.1:{server.server_port}/movie.m3u8'], check=True)
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


if __name__ == '__main__':
    main()
