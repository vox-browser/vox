import tempfile
import unittest
from pathlib import Path

from prepare_linux_modules import patch_module, stage_module


class LinuxModuleStagingTest(unittest.TestCase):
    def test_graphics_sampler_capacity_tracks_the_image_pool(self):
        original = """module gg
fn gg_init_sokol_window(user_data voidptr) {
\tdesc := sapp.create_desc()
\tgfx.setup(&desc)
}
"""
        with tempfile.TemporaryDirectory() as directory:
            source, target = Path(directory) / 'compiler/gg', Path(directory) / 'staged'
            source.mkdir(parents=True)
            (source / 'gg.c.v').write_text(original)
            stage_module(source, target, 'gg')
            patched = (target / 'gg.c.v').read_text()
            self.assertIn(
                '\tmut desc := sapp.create_desc()\n'
                '\tif desc.sampler_pool_size < desc.image_pool_size {\n'
                '\t\tdesc.sampler_pool_size = desc.image_pool_size\n'
                '\t}\n\tgfx.setup(&desc)', patched)
            self.assertEqual(patch_module('gg', patched), patched)
            self.assertEqual((source / 'gg.c.v').read_text(), original)
            self.assertEqual(patch_module('net/openssl', original), original)

    def test_optional_graphics_helpers_follow_their_callers(self):
        source = """module gg
const err_multiwindow_render_nil_callback = 'nil callback'
const err_multiwindow_render_device_lost = 'device lost'
fn gg_poison_gfx_render_owner(owner int) {
    poison(owner)
}
fn gg_fail_fn(msg string) {
    println(msg)
}
// fail_userdata_cb: gg_fail_fn
"""
        patched = patch_module('gg', source)
        self.assertIn('$if gg_multiwindow ? || test {\n\tconst err_multiwindow_render_nil_callback', patched)
        self.assertIn("\nconst err_multiwindow_render_device_lost = 'device lost'", patched)
        self.assertIn('$if gg_multiwindow ? || test {\n\tfn gg_poison_gfx_render_owner', patched)
        self.assertNotIn('fn gg_fail_fn', patched)

    def test_recording_helpers_keep_the_recording_and_test_conditions(self):
        source = """module gg
import os
fn new_gg_recorder_settings() &SSRecorderSettings {
    return &SSRecorderSettings{}
}
const recorder_settings = new_gg_recorder_settings()
"""
        patched = patch_module('gg', source)
        self.assertIn('$if gg_record ? || test {\n\timport os\n}', patched)
        self.assertIn('$if gg_record ? || test {\n\tfn new_gg_recorder_settings', patched)
        self.assertIn('$if gg_record ? || test {\n\tconst recorder_settings', patched)

    def test_sources_assets_refresh_and_compiler_is_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, target = root / 'compiler/gg', root / 'modules/gg'
            (source / 'render').mkdir(parents=True)
            original = 'usize(count) * usize(sizeof(Vertex))\nu64(usize(voidptr(context)))'
            (source / 'render/context.v').write_text(original)
            (source / 'shader.h').write_text('shader asset')
            stage_module(source, target, 'gg')
            patched = (target / 'render/context.v').read_text()
            self.assertIn('uint(count) * uint(sizeof(Vertex))', patched)
            self.assertIn('u64(voidptr(context))', patched)
            self.assertEqual((target / 'shader.h').read_text(), 'shader asset')
            self.assertEqual((source / 'render/context.v').read_text(), original)
            stage_module(source, target, 'gg')
            self.assertEqual((target / 'render/context.v').read_text(), patched)
            (source / 'shader.h').unlink()
            stage_module(source, target, 'gg')
            self.assertFalse((target / 'shader.h').is_symlink())

    def test_stbi_keeps_windows_clang_os_import(self):
        with tempfile.TemporaryDirectory() as directory:
            source, target = Path(directory) / 'stbi', Path(directory) / 'staged'
            source.mkdir()
            (source / 'stbi.c.v').write_text('import os\n$if windows { $if clang { os.args } }')
            stage_module(source, target, 'stbi')
            self.assertIn('$if windows && clang {\n\timport os\n}\n',
                          (target / 'stbi.c.v').read_text())

    def test_tls_keeps_borrowed_write_buffer(self):
        with tempfile.TemporaryDirectory() as directory:
            source, target = Path(directory) / 'openssl', Path(directory) / 'staged'
            source.mkdir()
            original = 'unsafe {\n\tmut ptr_base := bytes\n\tptr := ptr_base + offset\n}'
            (source / 'ssl_connection.c.v').write_text(original)
            stage_module(source, target, 'net/openssl')
            patched = (target / 'ssl_connection.c.v').read_text()
            self.assertTrue(patched.startswith('mut ptr_base := unsafe { bytes }\nunsafe {\n'))
            stage_module(source, target, 'net/openssl')
            self.assertEqual((target / 'ssl_connection.c.v').read_text(), patched)
            self.assertEqual((source / 'ssl_connection.c.v').read_text(), original)


if __name__ == '__main__':
    unittest.main()
