module buildtools

import os
import json2 as json
import time

fn gg_patches(canvas string, name string) ! {
	all := json.parse($embed_file('gg_patches.json').to_string())!.as_map()
	for operation in (all[name] or { json.Null{} }).as_array() {
		row := operation.as_map()
		path := join(canvas, (row['file'] or { json.Null{} }).str())
		write_changed(path, replace_once(read(path)!, (row['old'] or { json.Null{} }).str(), (row['new'] or { json.Null{} }).str())!)!
	}
}

fn prepare_gg_canvas(canvas string) ! {
	layer := join(canvas, 'gpu_layer.v')
	if !os.is_file(layer) { return }
	if !read(layer)!.contains('mask_color') {
		gg_patches(canvas, 'prepare_gg_shadow')!
		path := join(canvas, 'shaders/paint_snippets.metal')
		text := read(path)!
		marker := '// @@ main_image\n'
		if text.count(marker) != 1 || !text.all_after(marker).trim_space().ends_with('float4 outColor_1 = _10_sk_csxform_prealpha;') {
			return error('Unsupported GG image shader tail')
		}
		write_changed(path, text.all_before(marker) + marker + snippet('gg_image_shader'))!
		write_changed(join(canvas, 'vox_shadow_mask.v'), read(join(root_dir(), 'tools/ui2/gg_shadow_mask.v'))!)!
	}
	if !read(layer)!.contains('document_linear_filter') { gg_patches(canvas, 'prepare_gg_image')! }
	image_helper := read(join(root_dir(), 'tools/ui2/gg_document_image.v'))!
	if image_helper.contains('struct DocumentImageColorTransform') && !read(layer)!.contains('color_transform') {
		gg_patches(canvas, 'prepare_gg_gamma')!
	}
	write_changed(join(canvas, 'vox_document_image.v'), image_helper)!
}

fn prepare_gg_gradient(modules string, vlib string) ! {
	source := join(vlib, 'gg')
	gradient := join(source, 'canvas/gpu_gradient.v')
	if !os.is_file(gradient) { return }
	original := "(snippets['bodies_tile'] + snippets['body_colorize_\${stops}']).replace('_skTemp',"
	text := read(gradient)!.replace('bodies_tile := ' + original, "tile_source := snippets['bodies_tile'] + snippets['body_colorize_\${stops}']\n\tbodies_tile := tile_source.replace('_skTemp',")
	target := join(modules, 'gg')
	mkdir(target)!
	for entry in listing(source)! {
		if os.file_name(entry) == 'canvas' { continue }
		if os.is_dir(entry) {
			link_files(join(target, os.file_name(entry)), entry)!
		} else {
			link_to(join(target, os.file_name(entry)), entry)!
		}
	}
	canvas := join(target, 'canvas')
	mkdir(canvas)!
	for entry in listing(join(source, 'canvas'))! {
		output := join(canvas, os.file_name(entry))
		if entry == gradient {
			write_changed(output, text)!
		} else if os.is_file(entry) && entry.ends_with('.v') && read(entry)!.contains('fn C.') {
			mut context := read(entry)!
			for line in context.split_into_lines() {
				directive := line.trim_space()
				if !directive.starts_with('#include "@DIR/') || !directive.ends_with('.h"') {
					continue
				}
				name := directive.all_after('#include "@DIR/').trim_right('"')
				if !name.contains('darwin') && name != 'path_math.h' { continue }
				wrapper := 'vox_' + name.all_before_last('.') + '.m'
				header := real(join(source, 'canvas', name))
				if !os.is_file(header) { return error('Missing GG native helper: ${header}') }
				write_changed(join(canvas, wrapper), '#include ' + json.encode(header) + '\n')!
				context = context.replace(directive, '#include "@DIR/${wrapper}"')
			}
			write_changed(output, context)!
		} else if os.is_dir(entry) {
			link_files(output, entry)!
		} else {
			link_to(output, entry)!
		}
	}
	prepare_gg_canvas(canvas)!
}

fn prepare_sokol(modules string, vlib string) !string {
	helper := join(root_dir(), 'native/include/native_gg_metal_transfer.h')
	source := join(os.dir(vlib), 'thirdparty/sokol/sokol_gfx.h')
	declaration := join(vlib, 'sokol/c/declaration.c.v')
	original := read(declaration)!
	include := '#include "sokol_gfx.h"'
	if original.count(include) != 1 { return error('Unsupported Sokol native include') }
	text := read(source)!
	start := '_SOKOL_PRIVATE bool _sg_v_mtl_transfer('
	ending := '\n}\n#endif\n\n#if defined(_SOKOL_ANY_GL)'
	if text.count(start) != 1 { return error('Unsupported Sokol Metal transfer') }
	first := text.index(start) or { return error('Missing Metal transfer') }
	last := (text.index_after(ending, first) or { return error('Missing Metal transfer end') }) + 2
	body := text[first..last]
	for token in ['_sg_v_mtl_flush()', '[cmd_buffer waitUntilCompleted]', 'copyFromTexture:tex',
		'_SG_OBJC_RELEASE(staging)'] {
		if body.count(token) != 1 { return error('Unsupported Sokol Metal transfer: ${token}') }
	}
	header := text[..first] + body.replace_once('_sg_v_mtl_transfer(', '_sg_v_mtl_transfer_separate(') + '\n#include ' + json.encode(real(helper)) + text[last..]
	sha := hash(read(@FILE)! + real(vlib) + header + read(helper)! + original)
	root := build_cache('v/native-gg-runtime', sha)
	mkdir(os.dir(root))!
	mut held := acquire(root + '.lock', false)!
	defer { held.release() }
	staged_text := original.replace(include, '#include ' + json.encode(join(root, 'sokol_gfx.h')))
	outputs := {
		'sokol_gfx.h':     header
		'declaration.c.v': staged_text
	}
	if exists(root) {
		for name, value in outputs {
			if !os.is_file(join(root, name)) || read(join(root, name))! != value {
				return error('Modified staged Sokol runtime: ${root}')
			}
		}
	} else {
		tmp := temporary(os.dir(root), 'metal-')!
		defer { remove(tmp) or {} }
		for name, value in outputs { os.write_file(join(tmp, name), value)! }
		write_json(join(tmp, 'manifest.json'), json.Any(map[string]json.Any{
			'source':        real(source)
			'source_sha256': digest(source)!
			'helper':        helper
			'helper_sha256': digest(helper)!
			'sha256':        sha
		}))!
		os.rename(tmp, root)!
	}
	os.utime(root, time.now().unix(), time.now().unix())!
	link_files(join(modules, 'sokol'), join(vlib, 'sokol'))!
	link_to(join(modules, 'sokol/c/declaration.c.v'), join(root, 'declaration.c.v'))!
	return root
}

fn prepare_ui(selected string) !string {
	modules := os.getenv_opt('VMODULES') or { join(os.home_dir(), '.vmodules') }
	source := real(os.getenv_opt('UI2_SOURCE_DIR') or { join(modules, 'ui2') })
	for name in ['v.mod', 'ui/ui.v', 'ui/embedding.v'] {
		if !os.is_file(join(source, name)) {
			return error('UI2 is missing its embedding API. Update UI2 with v install ui2 / v up ui2, or set UI2_SOURCE_DIR.')
		}
	}
	target := build_cache(platform(), 'modules')
	mkdir(target)!
	link_to(join(target, 'ui2'), source)!
	vlib := real(join(os.dir(real(selected)), 'vlib'))
	prepare_gg_gradient(target, vlib)!
	$if macos {
		prepare_sokol(target, vlib)!
		macos := join(vlib, 'macos')
		if !os.is_file(join(macos, 'objc_bridge.h')) {
			return error('UI2 requires current V with vlib/macos')
		}
		cached := join(target, 'macos')
		if os.is_dir(cached) && !os.is_link(cached) { remove(cached)! }
		link_to(cached, macos)!
	}
	return target
}
