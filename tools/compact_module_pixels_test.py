"""Native ShadowRoot and JavaScriptCore module rendering against Brave."""
import sys
import unittest

import forum_news_inline_pixels_test as pixels


@unittest.skipUnless(sys.platform == 'darwin', 'Native module embedding is macOS-specific')
class CompactModulePixelsTests(unittest.TestCase):
    compare_fixture = pixels.ForumNewsInlinePixelsTests.compare_fixture

    def test_native_shadow_styles_and_imported_module_mutations_match_brave(self):
        self.compare_fixture('compact-shadow-module')


if __name__ == '__main__':
    unittest.main()
