"""Inactive scroll timelines preserve layout while document animations fill."""
import sys
import unittest

import forum_news_inline_pixels_test as pixels


@unittest.skipUnless(sys.platform == 'darwin', 'Native macOS screenshot check')
class ScrollAnimationPixelsTests(unittest.TestCase):
    def test_inactive_scroll_sidebar_matches_brave(self):
        pixels.ForumNewsInlinePixelsTests().compare_fixture('inactive-scroll-sidebar')


if __name__ == '__main__':
    unittest.main()
