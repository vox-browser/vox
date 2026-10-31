"""Match Brave's unavailable UI families and macOS system font aliases."""
import sys
import unittest

import forum_news_inline_pixels_test as pixels


@unittest.skipUnless(sys.platform == 'darwin', 'The reference uses macOS fonts')
class UiSansFontPixelsTests(unittest.TestCase):
    def test_ui_sans_fallback_matches_brave(self):
        pixels.ForumNewsInlinePixelsTests().compare_fixture('ui-sans-system-font')

    def test_apple_system_font_stack_matches_brave(self):
        pixels.ForumNewsInlinePixelsTests().compare_fixture('apple-system-font-stack')

    def test_unavailable_apple_system_uses_the_later_arial_face(self):
        pixels.ForumNewsInlinePixelsTests().compare_fixture('focused-empty-textarea', document_active=True)


if __name__ == '__main__':
    unittest.main()
