from pathlib import Path
import tempfile
import unittest

from prepare_ui2 import prepare_gg_gradient, prepare_ui2_source


class GGGradientCompatibilityTests(unittest.TestCase):
    def test_gradient_override_preserves_the_other_compiler_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            vlib, modules = root / 'vlib', root / 'modules'
            source = vlib / 'gg/canvas'
            source.mkdir(parents=True)
            modules.mkdir()
            shader = "module canvas\nfn shader() {\n\tbodies_tile := (snippets['bodies_tile'] + snippets['body_colorize_${stops}']).replace('_skTemp',\n\t\t'_skTempB')\n}\n"
            (source / 'gpu_gradient.v').write_text(shader)
            (source / 'other.v').write_text('module canvas\n')
            (source / 'gpu_context.v').write_text('module canvas\n#include "@DIR/gpu_metal_darwin.h"\nfn C.v_canvas_metal_device() voidptr\n')
            (source / 'gpu_metal_darwin.h').write_text('static void* v_canvas_metal_device(void) { return 0; }\n')
            (source / 'path.v').write_text('module canvas\nfn C.gg_canvas_sincosf(x f32, s &f32, c &f32)\n')
            (vlib / 'gg/gg.v').write_text('module gg\n')
            prepare_gg_gradient(modules, vlib)
            actual = (modules / 'gg/canvas/gpu_gradient.v').read_text()
            self.assertIn('bodies_tile := tile_source.replace(', actual)
            self.assertIn("tile_source := snippets['bodies_tile'] + snippets['body_colorize_${stops}']", actual)
            self.assertEqual((source / 'gpu_gradient.v').read_text(), shader)
            self.assertEqual((modules / 'gg/canvas/other.v').resolve(), source / 'other.v')
            self.assertFalse((modules / 'gg/canvas/gpu_context.v').is_symlink())
            self.assertIn('"@DIR/vox_gpu_metal_darwin.m"',
                          (modules / 'gg/canvas/gpu_context.v').read_text())
            self.assertIn(str(source / 'gpu_metal_darwin.h'),
                          (modules / 'gg/canvas/vox_gpu_metal_darwin.m').read_text())
            self.assertFalse((modules / 'gg/canvas/path.v').is_symlink())
            self.assertEqual((modules / 'gg/canvas/path.v').read_text(), (source / 'path.v').read_text())
            prepare_gg_gradient(modules, vlib)
            self.assertEqual((modules / 'gg/canvas/gpu_gradient.v').read_text(), actual)


class UpstreamUI2Tests(unittest.TestCase):
    def test_old_dependency_fails_with_an_update_instruction(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            source = root / 'source'
            source.mkdir()
            with self.assertRaisesRegex(RuntimeError, 'v up ui2'):
                prepare_ui2_source(source, root / 'modules/ui2')

    def test_upstream_checkout_replaces_the_private_patch_tree_and_is_not_modified(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            source, target = root / 'source', root / 'modules/ui2'
            (source / 'ui').mkdir(parents=True)
            (source / 'ui/embedding.v').write_text('module ui2\npub const embedded_controls_version = 1\n')
            target.mkdir(parents=True)
            (target / 'private.v').write_text('old generated implementation')
            before = (source / 'ui/embedding.v').read_bytes()
            prepare_ui2_source(source, target)
            self.assertTrue(target.is_symlink())
            self.assertEqual(target.resolve(), source)
            self.assertFalse((target / 'private.v').exists())
            self.assertEqual((source / 'ui/embedding.v').read_bytes(), before)
            prepare_ui2_source(source, target)
            self.assertEqual(target.resolve(), source)


if __name__ == '__main__':
    unittest.main()
