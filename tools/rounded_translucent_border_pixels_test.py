"""Rounded backgrounds and translucent borders share Brave's outer clip layer."""
import sys
import unittest

import forum_news_inline_pixels_test as pixels


@unittest.skipUnless(sys.platform == 'darwin', 'Reference uses native macOS rasterization')
class RoundedTranslucentBorderPixelsTests(unittest.TestCase):
    compare_fixture = pixels.ForumNewsInlinePixelsTests.compare_fixture

    def test_rounded_translucent_border_background_clip_layer(self):
        self.compare_fixture('rounded-translucent-border-clip-layer')


if __name__ == '__main__':
    unittest.main()
