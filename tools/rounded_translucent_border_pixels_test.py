"""Rounded backgrounds and translucent borders share Brave's outer clip layer."""
import sys
import unittest

import forum_news_inline_pixels_test as pixels


@unittest.skipUnless(sys.platform == 'darwin', 'Reference uses native macOS rasterization')
class RoundedTranslucentBorderPixelsTests(unittest.TestCase):
    compare_fixture = pixels.ForumNewsInlinePixelsTests.compare_fixture

    def test_rounded_translucent_border_background_clip_layer(self):
        self.compare_fixture('rounded-translucent-border-clip-layer')

    def test_transparent_border_clips_the_background_without_an_extra_layer(self):
        self.compare_fixture('rounded-transparent-border-background', width=1024, height=768)


if __name__ == '__main__':
    unittest.main()
