from contextlib import redirect_stderr
from io import StringIO
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import benchmark_github_page as benchmark
from libjs_capture_native_compiler import C_FLAGS


class PageEndpointTests(unittest.TestCase):
    def test_png_completion_waits_for_the_complete_end_chunk(self):
        with tempfile.TemporaryDirectory() as work:
            image = Path(work) / 'document.png'
            self.assertFalse(benchmark.png_write_complete(image))
            image.write_bytes(b'\x89PNG\r\n\x1a\n')
            self.assertFalse(benchmark.png_write_complete(image))
            with image.open('ab') as handle:
                handle.write(b'\x00\x00\x00\x00IEND\xaeB`')
            self.assertFalse(benchmark.png_write_complete(image))
            with image.open('ab') as handle:
                handle.write(b'\x82')
            self.assertTrue(benchmark.png_write_complete(image))

    def test_failed_first_launch_cannot_prevent_later_stability_checks(self):
        attempts = [dict(engine='brave', valid=False, folder='failed'),
                    dict(engine='libjs', valid=True, folder='different-engine'),
                    dict(engine='brave', valid=True, folder='baseline')]
        row = dict(engine='brave', valid=True, folder='candidate')
        with patch.object(benchmark, 'compare', return_value={'exact': False}) as compare:
            benchmark.check_capture_stability(row, attempts, Path('diff-tool'))
        compare.assert_called_once_with(Path('baseline/document.png'), Path('candidate/document.png'),
                                       Path('candidate/stability-diff.png'), Path('diff-tool'))
        self.assertFalse(row['valid'])


class NativeCacheOptionsTests(unittest.TestCase):
    common = [
        '--archive', 'archive', '--reference-audit', 'audit.json', '--reference-png', 'reference.png',
        '--output', 'output', '--memory-guard-registry', 'pids.json', '--engines', 'libjs-native',
        '--native-cache', 'cache', '--repeat', '1',
    ]

    def test_selects_the_capture_wrapper_for_preparation(self):
        argv = [*self.common, '--prepare-native-cache', '--native-captures', 'captures']
        with patch('sys.argv', ['benchmark', *argv]), patch.object(benchmark, 'run', return_value=0) as run:
            self.assertEqual(benchmark.main(), 0)
        args = run.call_args.args[0]
        self.assertEqual(args.native_captures, Path('captures'))
        self.assertEqual(args.native_compiler, benchmark.CAPTURE_COMPILER)

    def test_captures_require_preparation_and_the_wrapper(self):
        for extra in (
            ['--native-captures', 'captures'],
            ['--prepare-native-cache', '--native-captures', 'captures', '--native-compiler', '/usr/bin/clang'],
        ):
            with self.subTest(extra=extra):
                with patch('sys.argv', ['benchmark', *self.common, *extra]), redirect_stderr(StringIO()):
                    with self.assertRaises(SystemExit) as error:
                        benchmark.main()
                self.assertEqual(error.exception.code, 2)

    def test_capture_directory_cannot_overlap_the_cache(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            cache = root / 'cache'
            args = SimpleNamespace(output=root / 'output', archive=root / 'archive',
                vox=root / 'vox', brave=root / 'brave', engines=['libjs-native'], adblock_assets=None,
                prepare_native_cache=True, native_cache=cache, native_captures=cache / 'captures')
            with self.assertRaisesRegex(ValueError, 'separate directories'):
                benchmark.run(args)
            self.assertFalse(args.output.exists())

    def test_trace_can_be_requested_for_a_native_reopen(self):
        argv = [*self.common, '--trace-native-libraries']
        with patch('sys.argv', ['benchmark', *argv]), patch.object(benchmark, 'run', return_value=0) as run:
            self.assertEqual(benchmark.main(), 0)
        self.assertTrue(run.call_args.args[0].trace_native_libraries)

    def test_trace_requires_a_prepared_native_cache_and_a_native_reopen(self):
        for extra, common in (
            (['--prepare-native-cache'], self.common),
            (['--engines', 'libjs'], self.common),
            ([], self.common[:-4] + ['--repeat', '1']),
        ):
            with self.subTest(extra=extra, common=common):
                argv = ['benchmark', *common, '--trace-native-libraries', *extra]
                with patch('sys.argv', argv), redirect_stderr(StringIO()) as stderr:
                    with self.assertRaises(SystemExit) as error:
                        benchmark.main()
                self.assertEqual(error.exception.code, 2)
                self.assertIn('requires a libjs-native reopen', stderr.getvalue())


class V8EngineOptionsTests(unittest.TestCase):
    common = [
        '--archive', 'archive', '--reference-audit', 'audit.json', '--reference-png', 'reference.png',
        '--output', 'output', '--memory-guard-registry', 'pids.json', '--repeat', '1',
    ]

    def test_v8_engine_takes_its_private_executable(self):
        argv = [*self.common, '--engines', 'v8', 'jsc', '--v8-vox', 'v8/Vox']
        with patch('sys.argv', ['benchmark', *argv]), patch.object(benchmark, 'run', return_value=0) as run:
            self.assertEqual(benchmark.main(), 0)
        self.assertEqual(run.call_args.args[0].v8_vox, Path('v8/Vox'))

    def test_v8_engine_and_executable_require_each_other(self):
        for extra in (['--engines', 'v8'], ['--engines', 'jsc', '--v8-vox', 'v8/Vox']):
            with self.subTest(extra=extra):
                with patch('sys.argv', ['benchmark', *self.common, *extra]), redirect_stderr(StringIO()):
                    with self.assertRaises(SystemExit) as error:
                        benchmark.main()
                self.assertEqual(error.exception.code, 2)


class NativeCacheReceiptTests(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        root = Path(scratch.name)
        self.abi = 'a' * 64
        self.cache = root / 'cache'
        entries = self.cache / self.abi
        entries.mkdir(parents=True)
        self.library = entries / ('b' * 64 + '.dylib')
        self.library.write_bytes(b'fixture image')
        self.sha = benchmark.digest(self.library)
        key = 'c' * 64
        (entries / (key + '.json')).write_text(json.dumps(dict(
            key=key, abi=self.abi, library=self.library.name, library_sha256=self.sha, symbol=0)))
        self.captures = root / 'captures'
        batch = self.captures / self.sha
        batch.mkdir(parents=True)
        self.code = batch / 'code.c'
        self.code.write_text('void vox_native_0(void) {}\n')
        (batch / 'receipt.json').write_text(json.dumps(dict(
            source_sha256=benchmark.digest(self.code), library_sha256=self.sha, c_flags=list(C_FLAGS))))

    def verify(self):
        return benchmark.verify_compiler_captures(self.captures, self.cache, self.abi)

    def test_records_verified_captures_for_all_cache_libraries(self):
        self.assertEqual(self.verify(), dict(directory=str(self.captures), abi=self.abi, records=1,
            batches={self.library.name: dict(library_sha256=self.sha, source_sha256=benchmark.digest(self.code))}))

    def test_missing_or_changed_cannot_supply_a_capture_receipt(self):
        self.code.write_text('void vox_native_0(void) { int changed = 1; }\n')
        with self.assertRaisesRegex(ValueError, 'Captured C digest mismatch'):
            self.verify()
        self.code.with_name('receipt.json').unlink()
        with self.assertRaises(FileNotFoundError):
            self.verify()
        self.library.write_bytes(b'changed image')
        with self.assertRaisesRegex(ValueError, 'Prepared library digest mismatch'):
            self.verify()

    def test_trace_receipt_verifies_libraries_for_the_observed_browser_pid(self):
        trace = self.cache.parent / 'native-library-trace.log'
        unknown = self.library.with_name('d' * 64 + '.dylib')
        trace.write_text(f'dyld[42]: <uuid> {self.library}\ndyld[43]: <uuid> {unknown}\n')
        expected = dict(pid=42, path=str(trace.resolve()), sha256=benchmark.digest(trace),
                        abi=self.abi, libraries=[self.library.name])
        self.assertEqual(benchmark.verify_native_library_trace(trace, self.cache, self.abi, 42), expected)
        with self.assertRaisesRegex(ValueError, 'Traced libraries lack cache records'):
            benchmark.verify_native_library_trace(trace, self.cache, self.abi, 43)
        with self.assertRaisesRegex(ValueError, 'No native cache libraries'):
            benchmark.verify_native_library_trace(trace, self.cache, self.abi, 44)

    def test_reused_batches_can_finish_an_interrupted_seed(self):
        stats = dict(engine='libjs', native_context_initialized=False, native=dict(
            abi=self.abi, identity_kind='generated-code', cache_hits=5, invalid_entries=0, last_error='',
            pending_executables=0, compiler_invocations=0, compiled_executables=0))
        self.assertEqual(benchmark.cache_errors(stats, stats, preparing=True, diagnostics=False, resuming=True), [])
        self.assertIn('shutdown: cache preparation incomplete',
                      benchmark.cache_errors(stats, stats, preparing=True, diagnostics=False))
        stats['native']['pending_executables'] = 1
        self.assertIn('shutdown: cache preparation incomplete',
                      benchmark.cache_errors(stats, stats, preparing=True, diagnostics=False, resuming=True))


if __name__ == '__main__':
    unittest.main()
