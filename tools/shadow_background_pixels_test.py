"""Opaque background clipping and outer shadow composition against Brave."""
import sys
import unittest

import forum_news_inline_pixels_test as pixels


@unittest.skipUnless(sys.platform == 'darwin', 'Reference uses the macOS renderer')
class ShadowBackgroundPixelsTests(unittest.TestCase):
    compare_fixture = pixels.ForumNewsInlinePixelsTests.compare_fixture

    def test_padding_background_exposes_shadows_beneath_translucent_borders(self):
        self.compare_fixture('padding-background-outer-shadows')


if __name__ == '__main__':
    unittest.main()
