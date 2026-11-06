#!/usr/bin/env python3
"""Check retained scroll tiles, CPU fallback and actual Core Animation pixels."""
import argparse
import os
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    args.output.mkdir(parents=True, exist_ok=False)
    for name, flags in [('optimized', ['-O2']),
                        ('sanitized', ['-O1', '-g', '-fsanitize=address,undefined']),
                        ('non_arc', ['-O2', '-fno-objc-arc'])]:
        binary = args.output.resolve() / name
        command = ['clang++', '-std=c++20', '-fobjc-arc', *flags,
                   '-framework', 'Cocoa', '-framework', 'QuartzCore',
                   '-framework', 'Metal', '-framework', 'IOSurface',
                   str(root / 'tools/native_scroll_tile_presentation_test.mm'), '-o', str(binary)]
        with (args.output / (name + '.log')).open('w') as log:
            subprocess.run(command, check=True, stdout=log, stderr=subprocess.STDOUT)
            subprocess.run([str(binary)], check=True, stdout=log, stderr=subprocess.STDOUT)
            subprocess.run([str(binary)], env={**os.environ, 'VOX_GPU_FRAME_READINESS_QUEUE': '1'},
                           check=True, stdout=log, stderr=subprocess.STDOUT)
        print(name + ': passed', flush=True)


if __name__ == '__main__':
    main()
