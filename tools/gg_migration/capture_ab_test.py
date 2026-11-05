import importlib.util
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from PIL import Image

spec = importlib.util.spec_from_file_location('capture_ab', Path(__file__).with_name('capture_ab.py'))
capture_ab = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture_ab)


class CaptureValidationTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        root = Path(self.temporary.name)
        self.bundle = root / 'Vox.app'
        native = self.bundle / 'Contents/MacOS'
        native.mkdir(parents=True)
        (native / 'Vox').write_bytes(b'executable')
        self.library = native / 'libVoxGraphite.dylib'
        self.library.write_bytes(b'library')
        self.inputs = root / 'fixtures/input'
        self.inputs.mkdir(parents=True)
        (self.inputs / 'one.html').write_text('<p>one</p>')
        (self.inputs / 'two.html').write_text('<p>two</p>')
        self.args = SimpleNamespace(bundle=self.bundle, inputs=self.inputs,
                                    output=root / 'captures', candidate_env=['VOX_GG_SHAPES=1'],
                                    fixture_list=None, only=[], width=8, height=8,
                                    delay=0, timeout=1)

    @staticmethod
    def capture(browser, html, png, log, env, *unused):
        Image.new('RGBA', (8, 8), 'red').save(png)
        log.write_text('VOX_GG enabled text=false shapes=true paths=false\n'
                       if env.get('VOX_GG_DIAGNOSTICS') == '1' else '')
        return 0

    def run_captures(self, capture=None):
        with patch.object(capture_ab, 'capture', capture or self.capture):
            return capture_ab.run_captures(self.args, [])

    def test_identical_pixels_require_registered_adapters(self):
        def unregistered(*args):
            result = self.capture(*args)
            args[3].write_text('')
            return result
        rows, summary = self.run_captures(unregistered)
        self.assertTrue(summary['inputs_unchanged'])
        self.assertTrue(all(r['outcome'] == 'failed' for r in rows))
        self.assertIn('not registered', rows[0]['error'])

    def test_changed_native_library_invalidates_and_stops_cohort(self):
        def mutate(*args):
            result = self.capture(*args)
            self.library.write_bytes(b'new library')
            return result
        rows, summary = self.run_captures(mutate)
        self.assertFalse(summary['inputs_unchanged'])
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['outcome'], 'failed')

    def test_fixture_selection_keeps_named_cohort_and_progress(self):
        manifest = self.inputs.parent / 'cohort.txt'
        manifest.write_text('two\n')
        self.args.fixture_list = manifest
        rows, summary = self.run_captures()
        self.assertEqual([r['fixture'] for r in rows], ['two'])
        self.assertEqual(rows[0]['outcome'], 'equal')
        self.assertTrue(summary['inputs_unchanged'])
        self.assertEqual(json.loads((self.args.output / 'summary.json').read_text())['results'], rows)

    def test_shared_resource_change_is_an_identity_change(self):
        resources = self.inputs.parent / 'resources'
        resources.mkdir()
        image = resources / 'image.svg'
        image.write_text('<svg/>')
        before = capture_ab.input_identity(self.bundle, self.inputs)
        image.write_text('<svg><rect/></svg>')
        self.assertNotEqual(before, capture_ab.input_identity(self.bundle, self.inputs))

    def test_differences_and_abnormal_exits_fail_command(self):
        for outcome in ('different', 'unstable', 'failed'):
            with self.subTest(outcome=outcome), patch.object(capture_ab, 'run_captures', return_value=(
                    [{'fixture': 'one', 'outcome': outcome}], {'inputs_unchanged': True})):
                self.args.output.mkdir(exist_ok=True)
                with patch('sys.argv', ['capture_ab', '--bundle', str(self.bundle), '--inputs',
                                        str(self.inputs), '--output', str(self.args.output)]):
                    self.assertEqual(capture_ab.main(), 1)


if __name__ == '__main__':
    unittest.main()
