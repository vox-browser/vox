import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

from hacker_news_browser_instructions import fingerprint, reference_browser_apps


class BrowserBundleReuseTests(unittest.TestCase):
    def test_cohorts_reference_the_same_bundle_without_copying_or_changing_it(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'production/Vox.app'
            executable = source / 'Contents/MacOS/Vox'
            executable.parent.mkdir(parents=True)
            executable.write_bytes(b'production executable')
            for name in ('first', 'second'):
                output = root / name
                output.mkdir()
                with patch('shutil.copytree', side_effect=AssertionError('must not copy bundles')):
                    apps = reference_browser_apps(output, [('vox', source), ('control', source)])
                self.assertEqual(apps, dict(vox=source.resolve(), control=source.resolve()))
                for engine in apps:
                    link = output / engine / 'Vox.app'
                    self.assertTrue(link.is_symlink())
                    self.assertTrue((link / 'Contents/MacOS/Vox').samefile(executable))
                metadata = json.loads((output / 'browser-apps.json').read_text())
                self.assertEqual(metadata['apps']['vox'], str(source.resolve()))
                shutil.rmtree(output)
                self.assertEqual(executable.read_bytes(), b'production executable')

    def test_existing_input_pins_detect_a_rebuild_of_a_referenced_bundle(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'Vox.app'
            executable = source / 'Contents/MacOS/Vox'
            executable.parent.mkdir(parents=True)
            executable.write_bytes(b'before')
            output = root / 'cohort'
            output.mkdir()
            apps = reference_browser_apps(output, [('vox', source)])
            paths = {apps['vox'] / 'Contents/MacOS/Vox'}
            before = fingerprint(paths)
            replacement = executable.with_suffix('.new')
            replacement.write_bytes(b'after')
            replacement.replace(executable)
            self.assertNotEqual(fingerprint(paths), before)

    def test_missing_application_fails_before_creating_a_reference(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaises(FileNotFoundError):
                reference_browser_apps(root, [('vox', root / 'missing.app')])
            self.assertEqual(list(root.iterdir()), [])


if __name__ == '__main__':
    unittest.main()
