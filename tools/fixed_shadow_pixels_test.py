"""A fixed compositor picture preserves fractional shadow-color components."""
import sys
import unittest

import forum_news_inline_pixels_test as pixels


@unittest.skipUnless(sys.platform == 'darwin', 'Reference uses the macOS raster backend')
class FixedShadowPixelsTests(unittest.TestCase):
    compare_fixture = pixels.ForumNewsInlinePixelsTests.compare_fixture

    def test_fixed_picture_keeps_fractional_shadow_color(self):
        self.compare_fixture('chromium-fractional-fixed-shadow', width=1024, height=768,
                             settle_seconds=2)


if __name__ == '__main__':
    unittest.main()
