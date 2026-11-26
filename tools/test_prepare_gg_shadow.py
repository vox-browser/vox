import tempfile
import unittest
from pathlib import Path

from prepare_gg_shadow import prepare


class ShadowHelperStagingTest(unittest.TestCase):
    def test_refreshes_helper_after_the_abi_patch_is_already_installed(self):
        with tempfile.TemporaryDirectory() as directory:
            canvas = Path(directory)
            layer = canvas / 'gpu_layer.v'
            layer.write_text('// mask_color: already patched\n')
            helper = canvas / 'vox_shadow_mask.v'
            helper.write_text('// older implementation\n')
            prepare(canvas)
            canonical = Path(__file__).parent / 'ui2/gg_shadow_mask.v'
            self.assertEqual(helper.read_bytes(), canonical.read_bytes())
            self.assertIn('draw_linear_premultiplied_layer', helper.read_text())
            prepare(canvas)
            self.assertEqual(helper.read_bytes(), canonical.read_bytes())
            self.assertEqual(layer.read_text(), '// mask_color: already patched\n')

    def test_replaces_stale_helper_link_without_editing_its_target(self):
        with tempfile.TemporaryDirectory() as directory:
            canvas = Path(directory)
            (canvas / 'gpu_layer.v').write_text('// mask_color\n')
            previous = canvas / 'upstream.v'
            previous.write_text('// do not change upstream\n')
            helper = canvas / 'vox_shadow_mask.v'
            helper.symlink_to(previous)
            prepare(canvas)
            self.assertFalse(helper.is_symlink())
            self.assertEqual(previous.read_text(), '// do not change upstream\n')
            self.assertIn('draw_linear_premultiplied_layer', helper.read_text())


if __name__ == '__main__':
    unittest.main()
