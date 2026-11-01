"""SVG fills share the compositor's retained rounded ancestor clip."""
import sys
import unittest

import forum_news_inline_pixels_test as pixels


@unittest.skipUnless(sys.platform == 'darwin', 'Reference uses native macOS rasterization')
class CompositorRoundedSvgClipPixelsTests(unittest.TestCase):
    compare_fixture = pixels.ForumNewsInlinePixelsTests.compare_fixture

    def test_filled_paths_keep_rounded_ancestor_clips(self):
        self.compare_fixture('compositor-rounded-svg-clip')


if __name__ == '__main__':
    unittest.main()
