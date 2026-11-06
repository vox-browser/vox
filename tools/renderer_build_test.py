import tempfile
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from renderer_build import main, select_compiler


class RendererBuildTests(unittest.TestCase):
    def test_gg_receipt_does_not_claim_elimination_of_skia(self):
        with tempfile.TemporaryDirectory() as temporary:
            receipt=Path(temporary)/'renderer.json'
            with patch('sys.argv',['renderer_build','/v','--receipt',str(receipt)]), \
                    patch('renderer_build.has_gg_canvas',return_value=True):
                main()
            data=json.loads(receipt.read_text())
            self.assertEqual(data['default'],'gg')
            self.assertTrue(data['gg_adapters'])
            self.assertFalse(data['skia_free'])
            self.assertIn('canvas',data['skia_required_for'])

    def test_default_requires_the_gg_module(self):
        with patch('renderer_build.has_gg_canvas', return_value=False):
            with self.assertRaisesRegex(RuntimeError, 'default renderer requires'):
                select_compiler('/v')

    def test_explicit_compiler_is_never_silently_replaced(self):
        with patch('renderer_build.has_gg_canvas', return_value=False):
            with self.assertRaises(RuntimeError):
                select_compiler('/v', explicit=True, fallback=__file__)

    def test_automatic_selection_preserves_the_shared_compiler(self):
        with tempfile.TemporaryDirectory() as temporary:
            fallback = Path(temporary)/'gg-v'
            fallback.write_bytes(b'compiler')
            with patch('renderer_build.has_gg_canvas', side_effect=[False,True]):
                self.assertEqual(select_compiler('/shared/v', fallback=fallback), str(fallback))
            self.assertEqual(fallback.read_bytes(), b'compiler')

    def test_supported_compiler_and_explicit_legacy_do_not_fall_back(self):
        with patch('renderer_build.has_gg_canvas', return_value=True):
            self.assertEqual(select_compiler('/v'), '/v')
        with patch('renderer_build.has_gg_canvas', side_effect=AssertionError('no GG needed')):
            self.assertEqual(select_compiler('/v', legacy=True), '/v')
