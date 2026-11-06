import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from compare_prod_modes import refresh_native
from freeze_browser_compile import digest


class CommonNativeInputsTest(unittest.TestCase):
    def test_refresh_keeps_sealed_sources_and_non_native_pins_and_retains_old_receipts(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            library = root / 'Build/v/Vox.app/Contents/MacOS/libRenderer.dylib'
            library.parent.mkdir(parents=True)
            library.write_bytes(b'new shared renderer')
            output = root / 'comparison'
            (output / 'single').mkdir(parents=True)
            (output / 'parallel').mkdir()
            single = dict(live_inputs={str(library): 'old renderer', '/compiler': 'compiler pin'},
                          sealed_inputs={'/preprocessed-unit.i': 'source pin'}, complete=True)
            (output / 'single/frozen-compile.json').write_text(json.dumps(single))
            parallel = dict(live={str(library): 'old renderer', '/compiler': 'compiler pin'},
                            sealed={'/unit.i': 'source pin'})
            for name in ('link', 'unit_0'):
                (output / 'parallel' / (name + '.json')).write_text(json.dumps(parallel))
            (output / 'sealed-generation.json').write_text(json.dumps(dict(native_inputs={})))
            with patch('compare_prod_modes.ROOT', root):
                refresh_native(output)
                with self.assertRaisesRegex(RuntimeError, 'already attempted'):
                    refresh_native(output)
            changed = json.loads((output / 'single/frozen-compile.json').read_text())
            self.assertEqual(changed['live_inputs'], {str(library): digest(library), '/compiler': 'compiler pin'})
            self.assertEqual(changed['sealed_inputs'], single['sealed_inputs'])
            self.assertFalse(changed['complete'])
            backup = json.loads((output / 'single/frozen-compile.json.before-native-refresh').read_text())
            self.assertEqual(backup, single)
            for name in ('link', 'unit_0'):
                changed = json.loads((output / 'parallel' / (name + '.json')).read_text())
                self.assertEqual(changed['live'][str(library)], digest(library))
                self.assertEqual(changed['live']['/compiler'], 'compiler pin')
                self.assertEqual(changed['sealed'], parallel['sealed'])


if __name__ == '__main__':
    unittest.main()
