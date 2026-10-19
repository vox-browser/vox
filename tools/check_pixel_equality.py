#!/usr/bin/env python3
"""Compare rendered viewport PNGs; succeed only when every RGBA pixel matches."""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

REPO = Path(__file__).resolve().parents[1]


def compare(expected, actual, diff, executable):
    result = subprocess.run([str(executable), str(expected), str(actual), str(diff)],
                            capture_output=True, text=True, check=True)
    count = re.search(r'^different_pixels: ([0-9]+) ', result.stdout, re.MULTILINE)
    if count is None:
        raise RuntimeError('Pixel comparison did not report its differing-pixel count')
    return dict(exact=int(count[1]) == 0, different_pixels=int(count[1]),
                expected=str(expected), actual=str(actual), diff=str(diff), metrics=result.stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('expected', type=Path)
    parser.add_argument('actual', type=Path)
    parser.add_argument('diff', type=Path)
    parser.add_argument('--result', type=Path, help='Write a machine-readable verdict')
    parser.add_argument('--diff-tool', type=Path)
    args = parser.parse_args()
    executable = args.diff_tool
    if executable is None:
        executable = REPO / 'Build/pixel-equality/pixel_diff'
        executable.parent.mkdir(parents=True, exist_ok=True)
        compiler = os.environ.get('V_BIN') or shutil.which('v') or str(Path.home() / 'code/v/v')
        subprocess.run([compiler, '-o', str(executable),
                        str(REPO / 'tools/pixel_diff.v')], check=True)
    verdict = compare(args.expected, args.actual, args.diff, executable.resolve())
    if args.result:
        args.result.write_text(json.dumps(verdict, indent=2) + '\n')
    print(verdict['metrics'], end='')
    print('PASS: exact pixel equality' if verdict['exact'] else 'FAIL: pixels differ')
    return 0 if verdict['exact'] else 1


if __name__ == '__main__':
    sys.exit(main())
