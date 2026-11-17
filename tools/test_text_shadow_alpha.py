#!/usr/bin/env python3
"""Check single shadow opacity in a captured text-shadow-single-alpha fixture."""
import argparse
import json
from pathlib import Path
import struct
import zlib

from test_linux_browser import unfilter_png_row


def png_rows(path, size=(400, 180)):
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    width, height, depth, color, _, _, interlace = struct.unpack('>IIBBBBB', data[16:29])
    assert (width, height) == size
    assert depth == 8 and color in (2, 6) and interlace == 0
    channels = 4 if color == 6 else 3
    offset, compressed = 8, bytearray()
    while offset < len(data):
        length = struct.unpack('>I', data[offset:offset + 4])[0]
        if data[offset + 4:offset + 8] == b'IDAT':
            compressed.extend(data[offset + 8:offset + 8 + length])
        offset += length + 12
    decoded = zlib.decompress(compressed)
    stride = width * channels
    assert len(decoded) == (stride + 1) * height
    previous, rows = bytearray(stride), []
    for y in range(height):
        start = y * (stride + 1)
        row = unfilter_png_row(decoded[start], bytearray(decoded[start + 1:start + 1 + stride]), previous, channels)
        rows.append(row)
        previous = row
    return rows, channels


def check(path):
    rows, channels = png_rows(path)
    background = rows[0][:3]
    results = []
    # The half/full columns have the same integer x phase. Fractional quarter
    # opacity probes stay in the pixel reference, outside this linearity check.
    for index, blur in enumerate((0, 1, 3)):
        top, tested, maximum_error = 20 + index * 45, 0, 0
        full_total = half_total = active = 0
        for dy in range(-8, 32):
            row = rows[top + dy]
            for dx in range(-8, 64):
                assert row[(20 + dx) * channels:(20 + dx) * channels + 3] == background, 'zero-opacity shadow painted'
                full = background[1] - row[(305 + dx) * channels + 1]
                half = background[1] - row[(210 + dx) * channels + 1]
                full_total += full
                half_total += half
                active += full > 0 or half > 0
                if full < 32:
                    continue
                tested += 1
                error = abs(2 * half - full)
                maximum_error = max(maximum_error, error)
        assert tested >= 40, f'missing full-opacity shadow, blur={blur}, samples={tested}'
        # Blur/color conversion can move individual rounded mask samples even
        # in Brave. Integrated coverage must still scale once, within two byte
        # rounding steps per active sample. A quarter-alpha mask fails widely.
        total_error = abs(2 * half_total - full_total)
        assert total_error <= 2 * active, f'opacity applied twice: blur={blur}, total_error={total_error}, rounding_bound={2 * active}'
        results.append(dict(blur=blur, samples=tested, maximum_pixel_error=maximum_error,
                            integrated_error=total_error, rounding_bound=2 * active))
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    args = parser.parse_args()
    print(json.dumps(check(args.capture)))


if __name__ == '__main__':
    main()
