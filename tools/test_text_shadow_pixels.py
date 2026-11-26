#!/usr/bin/env python3
"""Require every text-shadow-single-alpha control pixel to match exactly."""
import argparse
from pathlib import Path

from test_text_shadow_alpha import png_rows


def check(reference, capture):
    expected, expected_channels = png_rows(reference)
    actual, actual_channels = png_rows(capture)
    different = 0
    for y in range(len(expected)):
        for x in range(400):
            a, b = x * expected_channels, x * actual_channels
            different += expected[y][a:a + 3] != actual[y][b:b + 3]
            if actual_channels == 4:
                assert actual[y][b + 3] == 255, 'nonopaque document capture'
    assert different == 0, f'text-shadow differing pixels: {different}'
    return different


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reference', type=Path)
    parser.add_argument('capture', type=Path)
    args = parser.parse_args()
    check(args.reference, args.capture)
    print('text shadows: zero differing pixels')


if __name__ == '__main__':
    main()
