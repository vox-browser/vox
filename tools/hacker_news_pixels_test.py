#!/usr/bin/env python3
"""Compare the frozen HN discussion with an unchanged Brave reference.

Run through tools/run_memory_bounded.py, as with other native browser tests.
"""

import os
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

from check_pixel_equality import REPO, compare


@unittest.skipUnless(sys.platform == 'darwin', 'The native reference uses macOS fonts and controls')
class HackerNewsPixelsTests(unittest.TestCase):
    def test_discussion_matches_brave_exactly(self):
        self.compare_fixture('hacker-news-item-50231722', 1024, 2048, scale=1)

    def test_initial_comment_text_matches_brave_on_retina(self):
        self.compare_fixture('hacker-news-comment-initial-text', 800, 600, scale=2)

    def test_complete_discussion_matches_brave_on_retina(self):
        self.compare_fixture('hacker-news-item-50231722-complete', 1024, 768,
                             scale=2, native_reference=True)

    def compare_fixture(self, name, width, height, scale, native_reference=False):
        fixtures = REPO / 'Tests/Browser/Brave'
        output = REPO / 'Build/hacker-news-pixels'
        output.mkdir(parents=True, exist_ok=True)
        compiler = os.environ.get('V_BIN') or shutil.which('v') or str(Path.home() / 'code/v/v')
        diff_tool = output / 'pixel_diff'
        subprocess.run([compiler, '-memory-limit', '10G', '-o', str(diff_tool),
                        str(REPO / 'tools/pixel_diff.v')], check=True)
        actual = output / f'{name}.actual.png'
        environment = dict(os.environ, LADYBIRD_SCREENSHOT_SCALE=str(scale),
                           VOX_SCREENSHOT_NATIVE_LAYOUT='1' if scale == 2 else '0',
                           VOX_CAPTURE_DOCUMENT_ONLY='0',
                           VFLAGS=(os.environ.get('VFLAGS', '') + ' -memory-limit 10G').strip())
        subprocess.run([str(REPO / 'capture_screenshot.sh'),
                        str(fixtures / 'input' / f'{name}.html'), str(actual),
                        str(width), str(height)], cwd=REPO, env=environment, check=True)
        expected = fixtures / 'expected' / f'{name}.png'
        if native_reference:
            # capture_screenshot.sh returns logical pixels. Apply its same
            # normalization to the immutable native-resolution Brave reference.
            normalized = output / f'{name}.expected-logical.png'
            subprocess.run(['sips', '--resampleHeightWidth', str(height), str(width),
                            str(expected), '--out', str(normalized)], check=True,
                           stdout=subprocess.DEVNULL)
            expected = normalized
        verdict = compare(expected, actual,
                          output / f'{name}.diff.png', diff_tool)
        (output / f'{name}.metrics.txt').write_text(verdict['metrics'])
        self.assertTrue(verdict['exact'], verdict['metrics'])


if __name__ == '__main__':
    unittest.main()
