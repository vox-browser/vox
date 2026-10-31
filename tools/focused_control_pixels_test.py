"""Native focused text controls against a focused Brave document."""
import sys
import unittest

import forum_news_inline_pixels_test as pixels


@unittest.skipUnless(sys.platform == 'darwin', 'Reference uses native macOS fonts')
class FocusedControlPixelsTests(unittest.TestCase):
    compare_fixture = pixels.ForumNewsInlinePixelsTests.compare_fixture

    def test_empty_focused_textarea_has_a_caret_and_placeholder(self):
        self.compare_fixture('focused-empty-textarea-arial', document_active=True)


if __name__ == '__main__':
    unittest.main()
