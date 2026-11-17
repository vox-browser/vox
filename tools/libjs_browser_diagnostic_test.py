"""Diagnostic source-selection regression sources; held with automated tests."""
import argparse
import contextlib
import io
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

import libjs_browser_diagnostic as diagnostic


class DiagnosticSourceTests(unittest.TestCase):
    def test_direct_urls_keep_paths_queries_and_fragments(self):
        for value in ['https://github.com/vlang/v',
                      'http://localhost:8080/page?q=one%20two#section']:
            with self.subTest(value=value):
                self.assertEqual(diagnostic.live_http_url(value), value)

    def test_invalid_direct_urls_decline_before_launch(self):
        for value in ['file:///tmp/page.html', '/relative', 'https://',
                      'https://user:secret@example.com/', 'https://example.com:70000/',
                      'https://[broken/', 'https://example.com/has space',
                      'https://example.com/\nother']:
            with self.subTest(value=value):
                with self.assertRaises(argparse.ArgumentTypeError):
                    diagnostic.live_http_url(value)

    def invoke(self, source_arguments):
        arguments = ['diagnostic', '--binary', '/tmp/Vox', '--output', '/tmp/result',
                     '--memory-guard-registry', '/tmp/pids.json', *source_arguments]
        with patch.object(sys, 'argv', arguments), patch.object(diagnostic, 'run', return_value=0) as run:
            try:
                diagnostic.main()
            except SystemExit as result:
                if result.code:
                    run.assert_not_called()
                    raise
                run.assert_called_once()
                return result.code, run.call_args.args[0]
            self.fail('The diagnostic CLI did not exit')

    def test_archive_and_direct_source_select_their_own_mode(self):
        result, arguments = self.invoke(['--archive', '/tmp/fixture'])
        self.assertEqual(result, 0)
        self.assertEqual(arguments.archive, Path('/tmp/fixture'))
        self.assertIsNone(arguments.url)
        result, arguments = self.invoke(['--url', 'https://github.com/vlang/v'])
        self.assertEqual(result, 0)
        self.assertEqual(arguments.url, 'https://github.com/vlang/v')
        self.assertIsNone(arguments.archive)

    def test_missing_or_conflicting_sources_never_launch(self):
        for source in [[], ['--archive', '/tmp/fixture', '--url', 'https://github.com/vlang/v']]:
            with self.subTest(source=source), contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as error:
                    self.invoke(source)
                self.assertEqual(error.exception.code, 2)


if __name__ == '__main__':
    unittest.main()
