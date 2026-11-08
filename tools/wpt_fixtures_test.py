from pathlib import Path
import subprocess
import tempfile
import unittest

from wpt_fixtures import PREFIXES, export_fixtures, verify_fixture_tree


class FixtureTests(unittest.TestCase):
    def test_export_pins_revision_preserves_bytes_and_rejects_mutations(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repo = root / 'upstream'
            repo.mkdir()
            def git(*args):
                return subprocess.check_output(['git', '-C', str(repo), *args],
                                               stderr=subprocess.DEVNULL, text=True).strip()
            git('init')
            for prefix in PREFIXES:
                path = repo / prefix / ('a.html' if '/input/' in prefix else 'a.txt')
                path.parent.mkdir(parents=True)
                path.write_bytes(b'original\r\n')
            (repo / 'unrelated.v').write_text('not a fixture')
            git('add', '.')
            git('-c', 'user.name=WPT fixture', '-c', 'user.email=fixture@example.test',
                'commit', '-m', 'fixture')
            revision = git('rev-parse', 'HEAD')
            fixtures, manifest = export_fixtures(repo, revision, root / 'cache')
            self.assertEqual(manifest['revision'], revision)
            self.assertFalse((fixtures / 'unrelated.v').exists())
            self.assertEqual((fixtures / PREFIXES[0] / 'a.html').read_bytes(), b'original\r\n')
            (repo / PREFIXES[0] / 'a.html').write_text('dirty working checkout')
            same, _ = export_fixtures(repo, revision, root / 'cache')
            self.assertEqual(same, fixtures)
            self.assertEqual(git('rev-parse', 'HEAD'), revision)
            (fixtures / PREFIXES[0] / 'a.html').write_text('changed')
            with self.assertRaisesRegex(ValueError, 'fixture changed'):
                verify_fixture_tree(fixtures, manifest)
            with self.assertRaisesRegex(ValueError, 'fixture changed'):
                export_fixtures(repo, revision, root / 'cache')

    def test_unlisted_resources_invalidate_the_fixture(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / PREFIXES[0] / 'extra.js'
            path.parent.mkdir(parents=True)
            path.write_text('extra')
            with self.assertRaisesRegex(ValueError, 'file list changed'):
                verify_fixture_tree(root, dict(files={}))


if __name__ == '__main__':
    unittest.main()
