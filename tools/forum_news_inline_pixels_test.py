"""Focused native rendering regressions extracted from the ten-site suite."""
import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

from check_pixel_equality import compare
from forum_news_pixels import REPO, VOX, executable_identity, guarded, write_json


@unittest.skipUnless(sys.platform == 'darwin', 'The reference uses native macOS fonts')
class ForumNewsInlinePixelsTests(unittest.TestCase):
    def compare_fixture(self, name):
        output = Path(tempfile.mkdtemp(prefix='forum-news-inline-', dir=REPO / 'Build'))
        fixture = REPO / 'Tests/Browser/Brave/input' / (name + '.html')
        reference = REPO / 'Tests/Browser/Brave/expected' / (name + '.png')
        actual = output / 'actual.png'
        environment = {k:v for k,v in os.environ.items()
                       if not k.lower().endswith('_proxy') and not k.startswith(('VOX_', 'LADYBIRD_', 'DYLD_', 'GC_'))}
        environment.update(VOX_PROFILE_DIR=str(output / 'profile'), VOX_TEST_WINDOW='1',
            VOX_CAPTURE_DOCUMENT_ONLY='1', LADYBIRD_SCREENSHOT_SCALE='1',
            LADYBIRD_SCREENSHOT_DELAY_SECONDS='0')
        identity = executable_identity(VOX)
        write_json(output / 'identity.json', identity)
        guarded([VOX, '--window-width', '800', '--window-height', '684',
                 '--screenshot', actual, fixture], output / 'capture', 60, environment)
        self.assertEqual(executable_identity(VOX), identity, 'Production bundle changed during capture')
        compiler = os.environ.get('V_BIN') or shutil.which('v') or str(Path.home() / 'code/v/v')
        tool = output / 'pixel_diff'
        guarded([compiler, '-memory-limit', '10G', '-nocache', '-o', tool,
                 REPO / 'tools/pixel_diff.v'], output / 'diff-tool', 60)
        verdict = compare(reference, actual, output / 'diff.png', tool)
        write_json(output / 'pixels.json', verdict)
        self.assertTrue(verdict['exact'], verdict['metrics'] + '\nArtifacts: ' + str(output))

    def test_middle_aligned_story_tags_match_brave_exactly(self):
        self.compare_fixture('lobsters-tag-alignment')

    def test_rounded_inline_backgrounds_match_brave_exactly(self):
        self.compare_fixture('lobsters-rounded-inline-background')

    def test_fractional_foregrounds_match_brave_exactly(self):
        self.compare_fixture('forum-fractional-foreground')

    def test_inline_backgrounds_and_borders_share_multisample_coverage(self):
        self.compare_fixture('lobsters-inline-msaa-compositing')


if __name__ == '__main__':
    unittest.main()
