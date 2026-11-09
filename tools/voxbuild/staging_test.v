module main

import os

fn test_linux_module_adapters_preserve_pointer_width_and_platform_guards() {
	assert patch_linux_module('gg', 'u64(usize(voidptr(a)))\nu64(usize(voidptr(b)))\nsize := usize(count)\n')! == 'u64(voidptr(a))\nu64(voidptr(b))\nsize := uint(count)\n'
	assert patch_linux_module('stbi', 'import os\n')! == r'$if windows && clang {' + '\n\timport os\n}\n'
	assert patch_linux_module('net/openssl', 'unsafe {\n\tmut ptr_base := bytes\n\tptr := ptr_base + offset\n}')! == 'mut ptr_base := unsafe { bytes }\nunsafe {\n\tptr := ptr_base + offset\n}'
}

fn test_sapp_canvas_default_keeps_static_pointer_and_original_source() {
	temporary := make_temp_directory(os.temp_dir(), 'vox-sapp-stage-test-')!
	defer { os.rmdir_all(temporary) or {} }
	source := os.join_path(temporary, 'compiler/sokol/sapp')
	target := os.join_path(temporary, 'modules/sokol/sapp')
	make_directory(source)!
	original := "module sapp\n@[typedef]\npub struct C.sapp_html5_desc {\npub:\n    canvas_selector &char = c'#canvas' // default CSS selector\n    canvas_resize bool\n}\npub type Html5Desc = C.sapp_html5_desc\nconst another_c_string = c'#canvas'\n"
	os.write_file(os.join_path(source, 'sapp_structs.c.v'), original)!
	stage_linux_module('', source, target, 'sokol/sapp')!
	patched := os.read_file(os.join_path(target, 'sapp_structs.c.v'))!
	assert patched.contains("canvas_selector &char = '#canvas'.str // default CSS selector")
	assert patched.contains("const another_c_string = c'#canvas'")
	assert patch_linux_module('sokol/sapp', patched)! == patched
	stage_linux_module('', source, target, 'sokol/sapp')!
	assert os.read_file(os.join_path(target, 'sapp_structs.c.v'))! == patched
	assert os.read_file(os.join_path(source, 'sapp_structs.c.v'))! == original
	assert patch_linux_module('gg', original)! == original
	spaced := "\tcanvas_selector\n\t&char\t=\n\tc'#canvas'\ncanvas_selector_extra &char = c'#canvas'\n// canvas_selector &char = c'#canvas'\n"
	assert patch_linux_module('sokol/sapp', spaced)! == spaced.replace_once("c'#canvas'", "'#canvas'.str")
}

fn test_optional_gg_helpers_keep_their_conditions_and_live_callbacks() {
	source := "module gg\nconst err_multiwindow_render_nil_callback = 'nil callback'\nconst err_multiwindow_render_device_lost = 'device lost'\nfn gg_poison_gfx_render_owner(owner int) {\n    poison(owner)\n}\nfn gg_fail_fn(msg string) {\n    println(msg)\n}\n// fail_userdata_cb: gg_fail_fn\n"
	patched := patch_linux_module('gg', source)!
	assert patched.contains(r'$if gg_multiwindow ? || test {' + '\n\tconst err_multiwindow_render_nil_callback')
	assert patched.contains("\nconst err_multiwindow_render_device_lost = 'device lost'")
	assert patched.contains(r'$if gg_multiwindow ? || test {' + '\n\tfn gg_poison_gfx_render_owner')
	assert !patched.contains('fn gg_fail_fn')
	assert patch_linux_module('gg', source + 'fn caller() {\n    gg_fail_fn("used")\n}\n')!.contains('fn gg_fail_fn')
}

fn staging_test_fontstash_source() string {
	return 'module gg\nfn fons_render_update(uptr voidptr, rect &i32, data &u8) {\n}\nfn fons_render_draw(uptr voidptr, verts &f32, tcoords &f32, colors &u32, nverts i32) {\n}\nfn create_fonts() {\n\tparams.renderUpdate = fons_render_update\n\tparams.renderDraw = fons_render_draw\n\tif memory_font {\n\t\tparams.renderUpdate = fons_render_update\n\t\tparams.renderDraw = fons_render_draw\n\t}\n}\n'
}

fn test_fontstash_adapter_rejects_incomplete_and_changed_upstream_callbacks() {
	source := staging_test_fontstash_source()
	patched := patch_fontstash_callbacks(source)!
	assert patched.count('C.vox_gg_fontstash_callbacks(&params)') == 2
	assert patched.contains("@[export: 'vox_gg_fontstash_render_update']")
	assert patch_fontstash_callbacks(patched)! == patched
	for changed in [source.replace('rect &i32', 'rect &int'),
		source.replace_once('\tparams.renderUpdate = fons_render_update\n', ''),
		patched.replace_once('C.vox_gg_fontstash_callbacks(&params)', 'partial_callback(&params)')] {
		if _ := patch_fontstash_callbacks(changed) {
			assert false, 'Changed callback layout must fail before staging'
		}
	}
}

fn test_linux_staging_detaches_linked_directories_and_refreshes_assets() {
	temporary := make_temp_directory(os.temp_dir(), 'vox-module-stage-test-')!
	defer { os.rmdir_all(temporary) or {} }
	source := os.join_path(temporary, 'compiler/gg')
	target := os.join_path(temporary, 'modules/gg')
	make_directory(os.join_path(source, 'render'))!
	make_directory(target)!
	original := 'usize(count) * usize(sizeof(Vertex))\nu64(usize(voidptr(context)))'
	os.write_file(os.join_path(source, 'render/context.v'), original)!
	os.write_file(os.join_path(source, 'shader.h'), 'shader asset')!
	os.symlink(os.join_path(source, 'render'), os.join_path(target, 'render'))!
	stage_linux_module('', source, target, 'gg')!
	assert !os.is_link(os.join_path(target, 'render'))
	assert os.read_file(os.join_path(source, 'render/context.v'))! == original
	assert os.read_file(os.join_path(target, 'render/context.v'))!.contains('u64(voidptr(context))')
	assert os.is_link(os.join_path(target, 'shader.h'))
	os.rm(os.join_path(source, 'shader.h'))!
	stage_linux_module('', source, target, 'gg')!
	assert !os.is_link(os.join_path(target, 'shader.h'))
}

fn test_prealloc_ownership_wrappers_and_capture_declarations_are_exact() {
	source := 'module closure\nfn closure_init_body() {\n\tinitialize()\n}\n'
	assert staging_wrap_function(source, 'fn closure_init_body()', '\tenter()\n', '\tleave()\n')! == 'module closure\nfn closure_init_body() {\n\tenter()\n\n\tinitialize()\n\tleave()\n}\n\n'
	for token in ['@VMODROOT', '@VEXEROOT'] {
		compat := 'module builtin\n' + r'$if !v3_c_extern_declarations ? {' + '\n\t#include "' + token + '/vlib/os/execute_capture_legacy.h"\n}\n'
		result := declare_capture_helpers(compat, '/resolved/v source/vlib/os/execute_capture_legacy.h')
		assert !result.contains(token)
		assert result.count('#include "/resolved/v source/vlib/os/execute_capture_legacy.h"') == 2
		assert declare_capture_helpers(result, '/resolved/v source/vlib/os/execute_capture_legacy.h') == result
	}
}

fn test_font_initializer_preserves_non_cmap_work_and_widens_loca() {
	source := "module ttf\npub fn (mut tf TTF_File) init() {\n    tf.read_offset_tables()\n    tf.read_head_table()\n    tf.read_cmap_table()\n    tf.read_kern_table()\n}\nfn (mut tf TTF_File) read_offset_tables() {\n    tf.pos = 0\n    for tag in tf.tables.keys() {\n        if tag != 'head' {\n            assert tf.calc_checksum(tf.tables[tag].offset, tf.tables[tag].length) == tf.tables[tag].checksum\n        }\n    }\n}\n"
	result := glyph_index_initializer(source)!
	assert !result.contains('tf.read_cmap_table()')
	assert !result.contains('tf.calc_checksum(')
	assert result.contains('tf.read_normalized_offset_tables()\n    tf.read_head_table()')
	assert result.contains('tf.read_kern_table()')
	assert result.ends_with('fn (mut tf TTF_File) read_normalized_offset_tables() {\n    tf.pos = 0\n    for tag in tf.tables.keys() {\n    }\n}\n')
	loca := 'offset = tf.get_u16() << 1\nnext = tf.get_u16() << 1\n'
	widened := widen_short_loca_offsets(loca)!
	assert widened == 'offset = u32(tf.get_u16()) << 1\nnext = u32(tf.get_u16()) << 1\n'
	assert widen_short_loca_offsets(widened)! == widened
	if _ := glyph_index_initializer(source.replace('== tf.tables[tag].checksum', '!= tf.tables[tag].checksum')) {
		assert false, 'Unknown upstream checksum validation must fail'
	}
	if _ := widen_short_loca_offsets('offset = tf.get_u16() << 1') {
		assert false, 'Partial short-loca patches must fail'
	}
}
