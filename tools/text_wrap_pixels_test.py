"""Native balance/pretty line breaks against an unchanged Brave reference."""
import sys
import unittest

import forum_news_inline_pixels_test as pixels


@unittest.skipUnless(sys.platform == 'darwin', 'Reference uses native macOS fonts')
class TextWrapPixelsTests(unittest.TestCase):
    compare_fixture = pixels.ForumNewsInlinePixelsTests.compare_fixture

    def test_balanced_and_pretty_home_copy_matches_brave(self):
        self.compare_fixture('balanced-home-copy')


if __name__ == '__main__':
    unittest.main()
