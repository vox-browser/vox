"""Fractionally translated carets match Chromium color-layer sampling."""
import sys
import unittest

import forum_news_inline_pixels_test as pixels


@unittest.skipUnless(sys.platform == 'darwin', 'Reference uses native macOS rasterization')
class CompositorFractionalCaretPixelsTests(unittest.TestCase):
    compare_fixture = pixels.ForumNewsInlinePixelsTests.compare_fixture

    def test_fractional_caret_caps_do_not_add_neighboring_ink(self):
        self.compare_fixture('compositor-fractional-caret', document_active=True)


if __name__ == '__main__':
    unittest.main()
