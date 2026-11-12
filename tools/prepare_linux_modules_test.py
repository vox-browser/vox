import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from prepare_linux_modules import patch_fontstash_callbacks, patch_module, stage_module


class LinuxModuleStagingTest(unittest.TestCase):
    def test_sapp_default_retains_static_canvas_pointer_without_rewriting_upstream(self):
        original = '''module sapp
@[typedef]
pub struct C.sapp_html5_desc {
pub:
    canvas_selector &char = c'#canvas' // default CSS selector
    canvas_resize bool
}
pub type Html5Desc = C.sapp_html5_desc
const another_c_string = c'#canvas'
'''
        with tempfile.TemporaryDirectory() as directory:
            source, target = Path(directory) / 'vlib/sokol/sapp', Path(directory) / 'modules/sokol/sapp'
            source.mkdir(parents=True)
            (source / 'sapp_structs.c.v').write_text(original)
            stage_module(source, target, 'sokol/sapp')
            patched = (target / 'sapp_structs.c.v').read_text()
            self.assertIn("canvas_selector &char = '#canvas'.str // default CSS selector", patched)
            self.assertIn("const another_c_string = c'#canvas'", patched)
            self.assertEqual(patch_module('sokol/sapp', patched), patched)
            stage_module(source, target, 'sokol/sapp')
            self.assertEqual((target / 'sapp_structs.c.v').read_text(), patched)
            self.assertEqual((source / 'sapp_structs.c.v').read_text(), original)
            self.assertEqual(patch_module('gg', original), original)

    def test_staging_removes_stale_dangling_links(self):
        with tempfile.TemporaryDirectory() as directory:
            source, target = Path(directory) / 'source', Path(directory) / 'target'
            source.mkdir()
            target.mkdir()
            (source / 'module.v').write_text('module sample\n')
            (target / 'old_test.v').symlink_to('/missing/compiler/old_test.v')
            stage_module(source, target, 'sample')
            self.assertFalse((target / 'old_test.v').is_symlink())
            self.assertEqual((target / 'module.v').read_text(), 'module sample\n')

    @staticmethod
    def fontstash_source():
        return '''module gg
fn fons_render_update(uptr voidptr, rect &i32, data &u8) {
}
fn fons_render_draw(uptr voidptr, verts &f32, tcoords &f32, colors &u32, nverts i32) {
}
fn create_fonts() {
\tparams.renderUpdate = fons_render_update
\tparams.renderDraw = fons_render_draw
\tif memory_font {
\t\tparams.renderUpdate = fons_render_update
\t\tparams.renderDraw = fons_render_draw
\t}
}
'''

    def test_fontstash_staging_adapts_both_paths_and_preserves_the_dependency(self):
        original = self.fontstash_source()
        with tempfile.TemporaryDirectory() as directory:
            source, target = Path(directory) / 'compiler/gg', Path(directory) / 'staged'
            source.mkdir(parents=True)
            (source / 'text_rendering.c.v').write_text(original)
            stage_module(source, target, 'gg')
            patched = (target / 'text_rendering.c.v').read_text()
            self.assertEqual(patched.count('C.vox_gg_fontstash_callbacks(&params)'), 2)
            self.assertIn("@[export: 'vox_gg_fontstash_render_update']", patched)
            self.assertIn("@[export: 'vox_gg_fontstash_render_draw']", patched)
            self.assertEqual(patch_fontstash_callbacks(patched), patched)
            self.assertEqual((target / 'vox_fontstash_callbacks.h').read_text(),
                             Path(__file__).with_name('linux_fontstash_callbacks.h').read_text())
            stage_module(source, target, 'gg')
            self.assertEqual((target / 'text_rendering.c.v').read_text(), patched)
            self.assertEqual((source / 'text_rendering.c.v').read_text(), original)

    def test_fontstash_staging_rejects_changed_signatures_and_assignment_counts(self):
        original = self.fontstash_source()
        for changed in [original.replace('rect &i32', 'rect &int'),
                        original.replace('\tparams.renderUpdate = fons_render_update\n', '', 1),
                        original + '\n\tparams.renderUpdate = fons_render_update\n\tparams.renderDraw = fons_render_draw\n']:
            with self.subTest(source=changed), self.assertRaises(RuntimeError):
                patch_fontstash_callbacks(changed)
        with self.assertRaises(RuntimeError):
            patch_fontstash_callbacks(patch_fontstash_callbacks(original).replace(
                'C.vox_gg_fontstash_callbacks(&params)', 'partial_callback(&params)', 1))

    def test_fontstash_adapter_has_the_const_c_abi_and_forwards_borrowed_buffers(self):
        compiler = os.environ.get('CC') or shutil.which('cc')
        if not compiler:
            self.skipTest('C compiler unavailable')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'fontstash.h').write_text('''typedef struct {
void (*renderUpdate)(void*, int*, const unsigned char*);
void (*renderDraw)(void*, const float*, const float*, const unsigned int*, int);
} FONSparams;
''')
            (root / 'adapter.h').write_text(Path(__file__).with_name('linux_fontstash_callbacks.h').read_text())
            (root / 'test.c').write_text('''#include <assert.h>
#include "adapter.h"
static int owner, updates, draws;
void vox_gg_fontstash_render_update(void* target, int32_t* rect, uint8_t* data) {
    assert(target == &owner && rect[0] == 3 && data[0] == 7); updates++;
}
void vox_gg_fontstash_render_draw(void* target, float* verts, float* coords, uint32_t* colors, int32_t count) {
    assert(target == &owner && verts[0] == 2 && coords[0] == 4 && colors[0] == 9 && count == 1); draws++;
}
int main(void) {
    FONSparams params = {0}; int rect[] = {3};
    const unsigned char data[] = {7}; const unsigned int colors[] = {9};
    const float verts[] = {2}, coords[] = {4};
    vox_gg_fontstash_callbacks(&params);
    params.renderUpdate(&owner, rect, data);
    params.renderDraw(&owner, verts, coords, colors, 1);
    assert(updates == 1 && draws == 1 && data[0] == 7 && verts[0] == 2 && coords[0] == 4 && colors[0] == 9);
    return 0;
}
''')
            subprocess.run([compiler, '-std=c11', '-Wall', '-Wextra', '-Werror', '-I', str(root),
                            str(root / 'test.c'), '-o', str(root / 'test')], check=True, capture_output=True)
            subprocess.run([str(root / 'test')], check=True, capture_output=True)

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
