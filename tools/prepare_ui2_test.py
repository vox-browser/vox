from pathlib import Path
import tempfile
import unittest

from prepare_linux_modules import stage_module
from prepare_ui2 import prepare_gg_gradient, prepare_ui2_source


class GGGradientCompatibilityTests(unittest.TestCase):
    def test_linux_and_ui2_stages_can_alternate_without_modifying_the_compiler(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            vlib, modules = root / 'vlib', root / 'modules'
            source = vlib / 'gg'
            contents = {
                'gg.v': 'module gg\nfn size(n int) uint { return usize(n) }\n',
                'render/context.v': 'module render\nfn size(n int) uint { return usize(n) }\n',
                'canvas/gpu_gradient.v': 'module canvas\n',
                'canvas/other.v': 'module canvas\n',
                'canvas/shaders/reference.metal': 'unchanged compiler shader',
            }
            for relative, content in contents.items():
                path = source / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content)
            stage_module(source, modules / 'gg', 'gg')
            for _ in range(2):
                prepare_gg_gradient(modules, vlib)
                stage_module(source, modules / 'gg', 'gg')
                self.assertIn('uint(n)', (modules / 'gg/render/context.v').read_text())
                self.assertFalse((modules / 'gg/render').is_symlink())
                self.assertEqual((modules / 'gg/canvas/shaders/reference.metal').resolve(),
                                 source / 'canvas/shaders/reference.metal')
                for relative, content in contents.items():
                    self.assertFalse((source / relative).is_symlink())
                    self.assertEqual((source / relative).read_text(), content)

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
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.source = self.root / 'current-ui2'
        self.target = self.root / 'modules/ui2'
        (self.source / 'ui').mkdir(parents=True)
        (self.source / 'v.mod').write_text("Module { name: 'ui2', subdirs: ['ui'] }\n")
        (self.source / 'ui/ui.v').write_text('module ui2\npub fn draw() {}\n')
        (self.source / 'ui/embedding.v').write_text(
            'module ui2\npub const embedded_controls_version = 1\n')

    def test_uses_live_checkout_without_git_or_copied_sources(self):
        prepare_ui2_source(self.source, self.target)
        self.assertTrue(self.target.is_symlink())
        self.assertEqual(self.target.resolve(), self.source)
        changed = 'module ui2\npub fn latest_draw() {}\n'
        (self.source / 'ui/ui.v').write_text(changed)
        (self.source / 'ui/new.v').write_text('module ui2\n')
        self.assertEqual((self.target / 'ui/ui.v').read_text(), changed)
        self.assertTrue((self.target / 'ui/new.v').is_file())
        self.assertEqual(list(self.target.parent.iterdir()), [self.target])

    def test_accepts_new_embedding_generations_without_a_revision_lock(self):
        (self.source / 'ui/embedding.v').write_text(
            'module ui2\npub const embedded_controls_version = 2\n')
        prepare_ui2_source(self.source, self.target)
        self.assertEqual(self.target.resolve(), self.source)

    def test_replaces_old_private_copy_and_retargets_an_existing_link(self):
        self.target.mkdir(parents=True)
        (self.target / 'private.v').write_text('obsolete copy')
        prepare_ui2_source(self.source, self.target)
        self.assertFalse((self.target / 'private.v').exists())
        newer = self.root / 'latest-ui2'
        self.source.rename(newer)
        prepare_ui2_source(newer, self.target)
        self.assertEqual(self.target.resolve(), newer)

    def test_repeated_preparation_preserves_checkout_contents(self):
        before = {p.relative_to(self.source): (p.read_bytes(), p.stat().st_mtime_ns)
                  for p in self.source.rglob('*') if p.is_file()}
        for _ in range(2):
            prepare_ui2_source(self.source, self.target)
        after = {p.relative_to(self.source): (p.read_bytes(), p.stat().st_mtime_ns)
                 for p in self.source.rglob('*') if p.is_file()}
        self.assertEqual(after, before)

    def test_missing_dependency_reports_installation_instructions(self):
        with self.assertRaisesRegex(RuntimeError, 'v install ui2 / v up ui2'):
            prepare_ui2_source(self.root / 'missing', self.target)
        self.assertFalse(self.target.exists())

    def test_incomplete_checkout_preserves_an_existing_link(self):
        prepare_ui2_source(self.source, self.target)
        incomplete = self.root / 'incomplete'
        incomplete.mkdir()
        with self.assertRaisesRegex(RuntimeError, 'embedding API'):
            prepare_ui2_source(incomplete, self.target)
        self.assertEqual(self.target.resolve(), self.source)


class GgCacheTests(unittest.TestCase):
    def test_repeated_preparation_preserves_compiler_sources(self):
        for linked_directory in [False, True]:
            with self.subTest(linked_directory=linked_directory), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                vlib, modules = root / 'vlib', root / 'modules'
                source, target = vlib / 'gg', modules / 'gg'
                (source / 'canvas').mkdir(parents=True)
                (source / 'canvas/shaders').mkdir()
                (source / 'render').mkdir()
                (source / 'keyboard.v').write_text('module gg\n')
                (source / 'render/render.v').write_text('module render\n')
                (source / 'render/helper.h').write_text('/* native renderer */\n')
                (source / 'canvas/gpu_gradient.v').write_text('module canvas\n')
                (source / 'canvas/shaders/fill.glsl').write_text('// native shader\n')
                target.mkdir(parents=True)
                (target / 'canvas').mkdir()
                (target / 'keyboard.v').write_text('stale cached module\n')
                if linked_directory:
                    (target / 'render').symlink_to(source / 'render', target_is_directory=True)
                    (target / 'canvas/shaders').symlink_to(source / 'canvas/shaders', target_is_directory=True)
                else:
                    (target / 'render').mkdir()
                    (target / 'render/render.v').write_text('stale renderer\n')
                    (target / 'canvas/shaders').mkdir()
                original = {p.relative_to(source): p.read_bytes() for p in source.rglob('*') if p.is_file()}
                for _ in range(2):
                    prepare_gg_gradient(modules, vlib)
                    self.assertFalse((target / 'render').is_symlink())
                    self.assertFalse((target / 'canvas/shaders').is_symlink())
                    stage_module(source, target, 'gg')
                    actual = {p.relative_to(source): p.read_bytes() for p in source.rglob('*') if p.is_file()}
                    self.assertEqual(actual, original)


if __name__ == '__main__':
    unittest.main()
