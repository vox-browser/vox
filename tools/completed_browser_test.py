import fcntl
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from completed_browser import completed_browser_lease, staged_browser_lease
from build_platform import production_state_dir


class CompletedBrowserTests(unittest.TestCase):
    def record(self, path, value):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value))

    def published(self, root):
        executable = root / 'Build/v/Vox.app/Contents/MacOS/Vox'
        executable.parent.mkdir(parents=True)
        executable.write_bytes(b'published')
        self.record(production_state_dir(root) / 'latest.json', dict(
            exit=0, executable=str(executable), executable_sha256=hashlib.sha256(b'published').hexdigest(),
            frozen_compilation=str(production_state_dir(root) / 'receipts/0001/frozen-compile.json')))
        return executable

    def staged(self, root, name='0002'):
        executable = root / ('Build/.production-output-' + name) / 'Vox.app/Contents/MacOS/Vox'
        executable.parent.mkdir(parents=True)
        executable.write_bytes(b'completed')
        ready = production_state_dir(root) / 'receipts' / name / 'ready.json'
        self.record(ready, dict(exit=0, ready_executable=str(executable),
                               ready_executable_sha256=hashlib.sha256(b'completed').hexdigest()))
        return executable, ready

    def assert_writer_available(self, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open('a') as file:
            fcntl.flock(file, fcntl.LOCK_EX | fcntl.LOCK_NB)

    def test_newest_completed_artifact_is_pinned_without_locking_published_bundle(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            self.published(root)
            executable, ready = self.staged(root)
            with completed_browser_lease(root) as selected:
                self.assertEqual(selected.executable, executable)
                self.assertTrue(selected.staged)
                self.assert_writer_available(production_state_dir(root) / 'bundle.lock')
                with self.assertRaises(BlockingIOError):
                    self.assert_writer_available(ready.parent / 'artifact.lock')
            self.assert_writer_available(ready.parent / 'artifact.lock')

    def test_unavailable_or_superseded_artifact_falls_back_to_protected_published_browser(self):
        for failure in ['removed', 'changed', 'superseded', 'failed', 'busy', 'malformed']:
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as directory:
                root = Path(directory).resolve()
                published = self.published(root)
                executable, ready = self.staged(root)
                if failure == 'removed':
                    executable.unlink()
                elif failure == 'changed':
                    executable.write_bytes(b'other app after exchange')
                elif failure == 'superseded':
                    self.record(ready.parent / 'result.json', dict(superseded=True))
                elif failure == 'failed':
                    self.record(ready.parent / 'result.json', dict(exit=1))
                elif failure == 'malformed':
                    ready.write_text('[]')
                with (ready.parent / 'artifact.lock').open('a') as writer:
                    if failure == 'busy':
                        fcntl.flock(writer, fcntl.LOCK_EX)
                    with patch('browser_bundle_lease.ROOT', root), completed_browser_lease(root) as selected:
                        self.assertEqual(selected.executable, published)
                        self.assertFalse(selected.staged)
                        with self.assertRaises(BlockingIOError):
                            self.assert_writer_available(production_state_dir(root) / 'bundle.lock')

    def test_older_staging_artifact_cannot_displace_a_newer_published_build(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            published = self.published(root)
            self.staged(root, '0000')
            with patch('browser_bundle_lease.ROOT', root), completed_browser_lease(root) as selected:
                self.assertEqual(selected.executable, published)

    def test_explicit_staging_path_must_still_have_a_completed_matching_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            self.published(root)
            executable, ready = self.staged(root)
            with completed_browser_lease(root, executable) as selected:
                self.assertEqual(selected.executable, executable)
                self.assertTrue(selected.staged)
            executable.unlink()
            with self.assertRaisesRegex(RuntimeError, 'no longer available'):
                with completed_browser_lease(root, executable):
                    self.fail('An unavailable executable must not reach the checker')

    def test_ready_receipt_removed_before_lock_acquisition_is_unavailable(self):
        with tempfile.TemporaryDirectory() as directory:
            with staged_browser_lease(Path(directory) / 'gone/ready.json') as selected:
                self.assertIsNone(selected)

    def test_changed_artifact_is_rejected_and_its_lease_is_released(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            executable, ready = self.staged(root)
            with self.assertRaisesRegex(RuntimeError, 'changed during'):
                with completed_browser_lease(root):
                    executable.write_bytes(b'changed outside managed publication')
            self.assert_writer_available(ready.parent / 'artifact.lock')

    def test_published_identity_must_match_its_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            executable = self.published(root)
            executable.write_bytes(b'changed')
            with patch('browser_bundle_lease.ROOT', root), self.assertRaisesRegex(RuntimeError, 'differs'):
                with completed_browser_lease(root):
                    self.fail('A mismatched executable must not reach the checker')

    def test_explicit_standalone_diagnostic_keeps_shared_native_helpers_protected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            executable = root / 'diagnostic'
            with patch('browser_bundle_lease.ROOT', root), completed_browser_lease(root, executable) as selected:
                self.assertIsNone(selected.receipt)
                self.assertEqual(selected.executable, executable)
                with self.assertRaises(BlockingIOError):
                    self.assert_writer_available(production_state_dir(root) / 'bundle.lock')
