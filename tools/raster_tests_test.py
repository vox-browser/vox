from pathlib import Path
import errno
import os
import subprocess
import tempfile
import unittest
from unittest import mock

import raster_tests


class RasterSuiteTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / 'source'
        self.source.mkdir()
        self.run_git('init', '--quiet')
        self.run_git('config', 'user.name', 'Raster tests')
        self.run_git('config', 'user.email', 'raster@example.invalid')
        tool = self.source / 'tools/gg_migration/example.py'
        tool.parent.mkdir(parents=True)
        tool.write_text('print("raster")\n')
        self.run_git('add', '.')
        self.run_git('commit', '--quiet', '-m', 'fixture')
        self.revision = self.run_git('rev-parse', 'HEAD')

    def run_git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.source), *args], text=True).strip()

    def test_fetch_uses_exact_revision_and_preserves_tools(self):
        checkout = raster_tests.ensure_checkout(str(self.source), self.revision, self.root / 'cache')
        self.assertEqual(raster_tests.tool_path(checkout, 'example.py').read_text(), 'print("raster")\n')
        self.assertEqual(raster_tests.git(checkout, 'rev-parse', 'HEAD'), self.revision)

    def test_changed_and_untracked_inputs_are_rejected(self):
        checkout = raster_tests.ensure_checkout(str(self.source), self.revision, self.root / 'cache')
        tool = raster_tests.tool_path(checkout, 'example.py')
        original = tool.read_text()
        tool.write_text('changed\n')
        with self.assertRaisesRegex(ValueError, 'uncommitted'):
            raster_tests.validate_checkout(checkout, self.revision)
        tool.write_text(original)
        (checkout / 'extra.py').write_text('changed\n')
        with self.assertRaisesRegex(ValueError, 'uncommitted'):
            raster_tests.validate_checkout(checkout, self.revision)

    def test_concurrent_fetch_validates_the_winning_checkout(self):
        for dirty in (False, True):
            checkout = self.root / ('dirty-cache' if dirty else 'clean-cache')

            def publish_other_checkout(temporary, destination):
                subprocess.run(['git', 'clone', '--quiet', str(self.source), str(destination)], check=True)
                if dirty:
                    (destination / 'extra.py').write_text('changed\n')
                # Exercise the platform's real error for a populated target.
                return os.rename(temporary, destination)

            with self.subTest(dirty=dirty), mock.patch.object(Path, 'rename', autospec=True,
                                                             side_effect=publish_other_checkout):
                if dirty:
                    with self.assertRaisesRegex(ValueError, 'uncommitted'):
                        raster_tests.ensure_checkout(str(self.source), self.revision, checkout)
                else:
                    self.assertEqual(raster_tests.ensure_checkout(str(self.source), self.revision,
                                                                  checkout), checkout)
            self.assertEqual(list(self.root.glob('.vox-tests-*')), [])

    def test_other_publication_errors_are_propagated(self):
        with mock.patch.object(Path, 'rename', side_effect=PermissionError(errno.EACCES, 'denied')):
            with self.assertRaises(PermissionError):
                raster_tests.ensure_checkout(str(self.source), self.revision, self.root / 'cache')
        self.assertEqual(list(self.root.glob('.vox-tests-*')), [])

    def test_wrong_revision_and_missing_explicit_checkout_fail_closed(self):
        with self.assertRaisesRegex(ValueError, 'revision differs'):
            raster_tests.validate_checkout(self.source, '0' * 40)
        with self.assertRaisesRegex(ValueError, 'does not exist'):
            raster_tests.ensure_checkout(str(self.source), self.revision, self.root / 'absent', fetch=False)

    def test_only_pinned_tool_files_are_addressable(self):
        for name in ['../../example.py', '/tmp/example.py', 'example.py/other']:
            with self.subTest(name=name), self.assertRaises(ValueError):
                raster_tests.tool_path(self.source, name)


if __name__ == '__main__':
    unittest.main()
