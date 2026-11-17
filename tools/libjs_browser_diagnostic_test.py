"""Diagnostic source-selection regression sources; held with automated tests."""
import argparse
import contextlib
import copy
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

    def test_strict_reuse_requires_native_cache_diagnostics_and_libjs(self):
        for extra in [[], ['--native-cache', '/tmp/cache'],
                      ['--native-diagnostics'], ['--native-cache', '/tmp/cache',
                       '--native-diagnostics', '--engine', 'javascriptcore']]:
            with self.subTest(extra=extra), contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as error:
                    self.invoke(['--url', 'https://github.com/vlang/v',
                                 '--require-native-reuse', *extra])
                self.assertEqual(error.exception.code, 2)
        result, arguments = self.invoke(['--url', 'https://github.com/vlang/v',
                                        '--require-native-reuse', '--native-cache', '/tmp/cache',
                                        '--native-diagnostics'])
        self.assertEqual(result, 0)
        self.assertTrue(arguments.require_native_reuse)

    def test_generated_code_identity_requires_an_explicit_libjs_cache(self):
        for extra in [[], ['--native-cache', '/tmp/cache', '--engine', 'javascriptcore']]:
            with self.subTest(extra=extra), contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as error:
                    self.invoke(['--url', 'https://github.com/vlang/v',
                                 '--generated-code-cache', *extra])
                self.assertEqual(error.exception.code, 2)
        result, arguments = self.invoke(['--url', 'https://github.com/vlang/v',
                                        '--generated-code-cache', '--native-cache', '/tmp/cache'])
        self.assertEqual(result, 0)
        self.assertTrue(arguments.generated_code_cache)


class NativeReuseAuditTests(unittest.TestCase):
    def receipt(self):
        return dict(engine='libjs', native_context_initialized=False,
                    native=dict(abi='pinned-abi', cache_hits=2, cache_misses=0,
                                invalid_entries=0, pending_executables=0,
                                compiled_executables=0, compiler_invocations=0, last_error=''),
                    native_execution=dict(entries=3))

    def test_both_capture_and_shutdown_must_prove_clean_native_execution(self):
        self.assertEqual(diagnostic.native_reuse_errors(self.receipt(), self.receipt()), [])
        for phase in [0, 1]:
            for key, value in [('cache_misses', 1), ('pending_executables', 1),
                               ('invalid_entries', 1), ('compiler_invocations', 1),
                               ('compiled_executables', 1), ('cache_hits', 0),
                               ('last_error', 'Native compiler exited 1: '), ('abi', '')]:
                with self.subTest(phase=phase, key=key):
                    receipts = [self.receipt(), self.receipt()]
                    receipts[phase]['native'][key] = value
                    self.assertTrue(diagnostic.native_reuse_errors(*receipts))

    def test_missing_counters_and_zero_activity_cannot_pass(self):
        for phase in [0, 1]:
            variants = [None, {}, self.receipt(), self.receipt(), self.receipt()]
            variants[2]['native_execution']['entries'] = 0
            variants[3]['native_context_initialized'] = True
            del variants[4]['native']['compiler_invocations']
            for variant in variants:
                with self.subTest(phase=phase, variant=variant):
                    receipts = [self.receipt(), self.receipt()]
                    receipts[phase] = copy.deepcopy(variant)
                    self.assertTrue(diagnostic.native_reuse_errors(*receipts))

    def test_shutdown_cannot_change_the_abi(self):
        final = self.receipt()
        final['native']['abi'] = 'another-abi'
        self.assertTrue(diagnostic.native_reuse_errors(self.receipt(), final))


if __name__ == '__main__':
    unittest.main()
