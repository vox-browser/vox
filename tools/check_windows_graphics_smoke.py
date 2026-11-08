#!/usr/bin/env python3
"""Check the Windows renderer smoke PNG (requires Pillow on the checking host)."""

import sys
from PIL import Image


def main():
    image = Image.open(sys.argv[1]).convert('RGB')
    assert image.size == (320, 240), image.size
    for point, color in [((30, 40), (255, 0, 0)),
                         ((200, 150), (0, 0, 255)),
                         ((0, 0), (255, 255, 255)),
                         ((120, 40), (255, 255, 255))]:
        actual = image.getpixel(point)
        assert actual == color, (point, actual, color)
    pixels = list(image.getdata())
    assert pixels.count((255, 0, 0)) == 80 * 50, 'red rectangle geometry'
    assert pixels.count((0, 0, 255)) == 60 * 70, 'blue rectangle geometry'
    dark = sum(max(pixel) < 128 for pixel in image.crop((20, 100, 150, 126)).getdata())
    assert dark > 50, ('font atlas coverage', dark)
    print('Windows GG projection, rectangle geometry, colors and text: passed')


if __name__ == '__main__':
    main()
