from pathlib import Path
import fcntl
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

from browser_bundle_lease import canonical_bundle_lease, publication_lease


class BrowserBundleLeaseTest(unittest.TestCase):
    def child(self, source, *arguments):
        process = subprocess.Popen([sys.executable, '-c',
                                    f'import sys; sys.path.insert(0, {str(Path(__file__).parent)!r});\n'
                                    + source, *map(str, arguments)],
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        def cleanup():
            if process.poll() is None:
                process.kill()
            process.communicate(timeout=5)
        self.addCleanup(cleanup)
        return process

    def wait_for_file(self, path, process):
        deadline = time.monotonic() + 5
        while not path.exists() and process.poll() is None and time.monotonic() < deadline:
            time.sleep(.01)
        self.assertTrue(path.exists(), 'lease child did not become ready')

    @unittest.skipUnless(sys.platform == 'darwin', 'macOS atomic app publication')
    def test_publication_waits_for_reader_without_replacing_the_app(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / 'Build/v/Vox.app/Contents/MacOS/Vox'
            staged = root / 'stage/Vox.app/Contents/MacOS/Vox'
            target.parent.mkdir(parents=True)
            staged.parent.mkdir(parents=True)
            target.write_bytes(b'old fixture')
            staged.write_bytes(b'new fixture')
            ready = root / 'ready'
            with publication_lease(root, shared=True):
                process = self.child('''from pathlib import Path
import rebuild_browser
root, stage, ready = map(Path, sys.argv[1:])
ready.touch()
rebuild_browser.publish(root, stage)
''', root, root / 'stage', ready)
                self.wait_for_file(ready, process)
                with self.assertRaises(subprocess.TimeoutExpired):
                    process.wait(timeout=.1)
                self.assertEqual(target.read_bytes(), b'old fixture')
            _, error = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 0, error.decode())
            self.assertEqual(target.read_bytes(), b'new fixture')

    def test_readers_can_share_the_same_bundle(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with publication_lease(root, shared=True):
                process = self.child('''from pathlib import Path
from browser_bundle_lease import publication_lease
with publication_lease(Path(sys.argv[1]), shared=True):
    pass
''', root)
                _, error = process.communicate(timeout=5)
                self.assertEqual(process.returncode, 0, error.decode())

    def test_exception_releases_the_lease(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaisesRegex(RuntimeError, 'capture failed'):
                with publication_lease(root, shared=True):
                    raise RuntimeError('capture failed')
            with (root / 'Build/production-build/bundle.lock').open('a') as file:
                fcntl.flock(file, fcntl.LOCK_EX | fcntl.LOCK_NB)
                fcntl.flock(file, fcntl.LOCK_UN)

    def test_canonical_path_alias_uses_the_shared_lease(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with patch('browser_bundle_lease.ROOT', root), \
                    patch('browser_bundle_lease.publication_lease') as lease:
                with canonical_bundle_lease(root / 'Build/v/../v/Vox.app'):
                    pass
                lease.assert_called_once_with(root, shared=True)

    def test_historical_bundle_does_not_block_the_canonical_publisher(self):
        with patch('browser_bundle_lease.publication_lease') as lease:
            with canonical_bundle_lease(Path('/historical/Vox.app')):
                pass
            lease.assert_not_called()


if __name__ == '__main__':
    unittest.main()
