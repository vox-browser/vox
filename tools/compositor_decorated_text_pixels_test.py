"""Promoted decorated text retains transparent compositor rounding."""
import sys
import unittest

import forum_news_inline_pixels_test as pixels


@unittest.skipUnless(sys.platform == 'darwin', 'Reference uses native macOS rasterization')
class CompositorDecoratedTextPixelsTests(unittest.TestCase):
    compare_fixture = pixels.ForumNewsInlinePixelsTests.compare_fixture

    def test_underlines_and_glyphs_share_the_promoted_text_surface(self):
        self.compare_fixture('compositor-underlined-footer')

    def test_clipped_rounded_box_keeps_its_leaf_compositor_surface(self):
        self.compare_fixture('compositor-rounded-leaf-layer')


if __name__ == '__main__':
    unittest.main()
