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
        name = 'hacker-news-item-50231722'
        fixtures = REPO / 'Tests/Browser/Brave'
        output = REPO / 'Build/hacker-news-pixels'
        output.mkdir(parents=True, exist_ok=True)
        compiler = os.environ.get('V_BIN') or shutil.which('v') or str(Path.home() / 'code/v/v')
        diff_tool = output / 'pixel_diff'
        subprocess.run([compiler, '-memory-limit', '10G', '-o', str(diff_tool),
                        str(REPO / 'tools/pixel_diff.v')], check=True)
        actual = output / f'{name}.actual.png'
        environment = dict(os.environ, LADYBIRD_SCREENSHOT_SCALE='1',
                           VOX_SCREENSHOT_NATIVE_LAYOUT='0', VOX_CAPTURE_DOCUMENT_ONLY='0',
                           VFLAGS=(os.environ.get('VFLAGS', '') + ' -memory-limit 10G').strip())
        subprocess.run([str(REPO / 'capture_screenshot.sh'),
                        str(fixtures / 'input' / f'{name}.html'), str(actual),
                        '1024', '2048'], cwd=REPO, env=environment, check=True)
        verdict = compare(fixtures / 'expected' / f'{name}.png', actual,
                          output / f'{name}.diff.png', diff_tool)
        (output / f'{name}.metrics.txt').write_text(verdict['metrics'])
        self.assertTrue(verdict['exact'], verdict['metrics'])


if __name__ == '__main__':
    unittest.main()
