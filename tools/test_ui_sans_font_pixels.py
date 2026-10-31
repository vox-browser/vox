"""The UI sans-serif generic uses Brave's macOS system face and metrics."""
import sys
import unittest

import forum_news_inline_pixels_test as pixels


@unittest.skipUnless(sys.platform == 'darwin', 'The reference uses macOS fonts')
class UiSansFontPixelsTests(unittest.TestCase):
    def test_ui_sans_system_font_matches_brave(self):
        pixels.ForumNewsInlinePixelsTests().compare_fixture('ui-sans-system-font')


if __name__ == '__main__':
    unittest.main()
