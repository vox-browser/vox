#!/usr/bin/env python3
"""Check logo fringe equality and overflow containment in the SVG viewport fixture.

Full-image pixel metrics remain separate: the compound overflow probes retain
known interior edge differences, outside this viewport-clipping property.
"""
import argparse
import json
from pathlib import Path

from test_text_shadow_alpha import png_rows


def check(reference, capture):
    expected, expected_channels = png_rows(reference, (400, 340))
    actual, actual_channels = png_rows(capture, (400, 340))
    if actual_channels == 4:
        assert all(row[x * 4 + 3] == 255 for row in actual for x in range(400)), 'nonopaque document capture'
    different = 0
    for y in range(250):
        for x in range(400):
            a, b = x * actual_channels, x * expected_channels
            different += actual[y][a:a + 3] != expected[y][b:b + 3]
    assert different == 0, f'logo differing pixels: {different}'
    background = expected[0][:3]
    tested = 0
    for left in (20, 120, 220):
        for y in range(260, 320):
            for x in range(left, left + 70):
                if x < left + 40 and y < 284:
                    continue
                a, b = x * actual_channels, x * expected_channels
                assert expected[y][b:b + 3] == background, 'reference overflow changed'
                assert actual[y][a:a + 3] == background, f'viewport overflow at {x},{y}'
                tested += 1
    return dict(logo_different_pixels=different, outside_viewport_samples=tested)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reference', type=Path)
    parser.add_argument('capture', type=Path)
    args = parser.parse_args()
    print(json.dumps(check(args.reference, args.capture)))


if __name__ == '__main__':
    main()
