#!/usr/bin/env python3
"""Run native GPU readiness/mailbox ownership checks under the memory guard."""
import argparse
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
                   '-framework', 'Cocoa', '-framework', 'QuartzCore', '-framework', 'IOSurface',
                   str(root / 'tools/native_frame_publication_test.mm'), '-o', str(binary)]
        with (args.output / (name + '.log')).open('w') as log:
            subprocess.run(command, check=True, stdout=log, stderr=subprocess.STDOUT)
            subprocess.run([str(binary)], check=True, stdout=log, stderr=subprocess.STDOUT)
        print(name + ': passed', flush=True)
    observer = args.output.resolve() / 'observer'
    command = ['clang', '-O2', '-fobjc-arc', '-Wl,-undefined,dynamic_lookup',
               '-framework', 'Cocoa', '-framework', 'QuartzCore',
               str(root / 'tools/native_frame_observer_test.m'), '-o', str(observer)]
    with (args.output / 'observer.log').open('w') as log:
        subprocess.run(command, check=True, stdout=log, stderr=subprocess.STDOUT)
        subprocess.run([str(observer)], check=True, stdout=log, stderr=subprocess.STDOUT)
    print('observer: passed', flush=True)


if __name__ == '__main__':
    main()
