"""Node prototype ordering must complete the page's startup script."""
import sys
import unittest

import forum_news_inline_pixels_test as pixels


@unittest.skipUnless(sys.platform == 'darwin', 'Native screenshot capture uses macOS')
class CompactNodePositionPixelsTests(unittest.TestCase):
    compare_fixture = pixels.ForumNewsInlinePixelsTests.compare_fixture

    def test_node_prototype_position_and_live_tree_order(self):
        self.compare_fixture('compact-node-position')


if __name__ == '__main__':
    unittest.main()
