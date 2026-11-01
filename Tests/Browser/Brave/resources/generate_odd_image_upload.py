#!/usr/bin/env python3
"""Regenerate the odd-sized, opaque CPU-resize regression input (requires Pillow)."""

from pathlib import Path
from PIL import Image


def main():
    width, height = 1191, 690
    image = Image.new('RGBA', (width, height))
    image.putdata([((x * 71 + y * 13) % 256,
                    (x * 19 + y * 137) % 256,
                    (x * 97 + y * 43) % 256, 255)
                   for y in range(height) for x in range(width)])
    image.save(Path(__file__).with_name('odd-image-upload.png'))


if __name__ == '__main__':
    main()
