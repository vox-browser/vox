"""CSS superellipse corners retain Brave's background, border and shadow raster."""
import sys
import unittest

import forum_news_inline_pixels_test as pixels


@unittest.skipUnless(sys.platform == 'darwin', 'Reference uses native macOS rasterization')
class CornerShapePixelsTests(unittest.TestCase):
    compare_fixture = pixels.ForumNewsInlinePixelsTests.compare_fixture

    def test_superellipse_backgrounds_borders_and_shadows(self):
        self.compare_fixture('corner-shape-superellipse')


if __name__ == '__main__':
    unittest.main()
