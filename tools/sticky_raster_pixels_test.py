"""Sticky raster origins include the live horizontal scroll-property offset."""
import sys
import unittest

import forum_news_inline_pixels_test as pixels


@unittest.skipUnless(sys.platform == 'darwin', 'Reference uses the macOS raster backend')
class StickyRasterPixelsTests(unittest.TestCase):
    compare_fixture = pixels.ForumNewsInlinePixelsTests.compare_fixture

    def test_sticky_vector_picture_keeps_rounded_message_coverage(self):
        self.compare_fixture('chromium-sticky-raster-space', width=1024, height=768,
                             settle_seconds=2)


if __name__ == '__main__':
    unittest.main()
