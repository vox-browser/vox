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


class NativeCaptureOptionsTests(unittest.TestCase):
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


class NativeCaptureReceiptTests(unittest.TestCase):
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


if __name__ == '__main__':
    unittest.main()
