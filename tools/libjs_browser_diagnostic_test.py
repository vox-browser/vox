"""Diagnostic source-selection regression sources; held with automated tests."""
import argparse
import contextlib
import copy
import io
import json
import os
from pathlib import Path
import sys
import tempfile
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


class HttpCacheIsolationTests(unittest.TestCase):
    def test_fresh_browser_processes_cannot_inherit_http_cache_state(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            shared = root / 'shared-cache'
            shared.mkdir()
            (shared / 'retained').write_text('ambient response')
            binary = root / 'fake-browser'
            binary.write_text('''#!/usr/bin/env python3
import json, os
from pathlib import Path
output = Path(os.environ['VOX_CAPTURE_AUDIT_PATH']).parent
cache = Path(os.environ['LADYBIRD_CACHE_DIR'])
before = sorted(p.name for p in cache.iterdir()) if cache.exists() else []
cache.mkdir(parents=True, exist_ok=True)
(cache / 'retained').write_text('private response')
(output / 'cache-launch.json').write_text(json.dumps(dict(cache=str(cache), before=before)))
Path(os.environ['VOX_NATIVE_OBSERVATION_SCREENSHOT']).write_bytes(b'fixture capture')
''')
            binary.chmod(0o755)
            with patch.dict(os.environ, {'LADYBIRD_CACHE_DIR': str(shared)}), \
                    patch.object(diagnostic, 'canonical_bundle_lease',
                                 return_value=contextlib.nullcontext()), \
                    patch.object(diagnostic, 'runtime_input_paths', return_value=[]), \
                    patch.object(diagnostic, 'publish_adopted_processes'):
                for name in ['first', 'second']:
                    output = root / name
                    arguments = ['diagnostic', '--binary', str(binary), '--output', str(output),
                                 '--url', 'https://example.com/', '--observe-ms', '1',
                                 '--timeout', '10', '--memory-guard-registry', str(root / 'pids.json')]
                    with patch.object(sys, 'argv', arguments), \
                            contextlib.redirect_stdout(io.StringIO()), \
                            self.assertRaises(SystemExit) as result:
                        diagnostic.main()
                    self.assertEqual(result.exception.code, 0)
                    launch = json.loads((output / 'cache-launch.json').read_text())
                    self.assertEqual(launch, dict(cache=str(output / 'http-cache'), before=[]))
                    summary = json.loads((output / 'summary.json').read_text())
                    self.assertEqual(summary['http_cache']['initial_entries'], 0)
                    self.assertEqual((output / 'http-cache/retained').read_text(), 'private response')
            self.assertEqual((shared / 'retained').read_text(), 'ambient response')
            self.assertEqual(sorted(p.name for p in shared.iterdir()), ['retained'])

    def test_preseeded_private_cache_declines_before_browser_launch(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            binary = root / 'fake-browser'
            binary.write_bytes(b'fixture identity')
            output = root / 'output'

            @contextlib.contextmanager
            def seed_cache(_):
                (output / 'http-cache/retained').write_text('unexpected preseed')
                yield

            arguments = ['diagnostic', '--binary', str(binary), '--output', str(output),
                         '--url', 'https://example.com/', '--memory-guard-registry', str(root / 'pids.json')]
            with patch.object(sys, 'argv', arguments), \
                    patch.object(diagnostic, 'canonical_bundle_lease', side_effect=seed_cache), \
                    patch.object(diagnostic, 'runtime_input_paths', return_value=[]), \
                    patch.object(diagnostic.subprocess, 'Popen') as process:
                with self.assertRaisesRegex(ValueError, 'HTTP cache must be empty'):
                    diagnostic.main()
                process.assert_not_called()


if __name__ == '__main__':
    unittest.main()
