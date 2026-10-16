import binascii
from pathlib import Path
import struct
import tempfile
import unittest
import zlib

from check_pixel_equality import compare, REPO


def write_png(path, rgba):
    def chunk(kind, data):
        return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', binascii.crc32(kind + data))
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!IIBBBBB', 1, 1, 8, 6, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress(b'\0' + bytes(rgba))) + chunk(b'IEND', b''))


class ExactPixelGateTests(unittest.TestCase):
    def test_real_png_comparisons_reject_even_one_channel_or_alpha_difference(self):
        tool = REPO / 'Build/pixel-equality/pixel_diff'
        self.assertTrue(tool.is_file(), 'Build the tool with check_pixel_equality.py before testing')
        with tempfile.TemporaryDirectory() as temporary:
            expected, actual, diff = [Path(temporary) / name for name in ['expected.png', 'actual.png', 'diff.png']]
            write_png(expected, [10, 20, 30, 255])
            for pixel, exact in [([10, 20, 30, 255], True), ([11, 20, 30, 255], False),
                                 ([10, 20, 30, 254], False)]:
                write_png(actual, pixel)
                verdict = compare(expected, actual, diff, tool)
                self.assertEqual(verdict['exact'], exact)
                self.assertEqual(verdict['different_pixels'], 0 if exact else 1)
                self.assertTrue(diff.is_file())


if __name__ == '__main__':
    unittest.main()
