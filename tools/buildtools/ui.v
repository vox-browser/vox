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

// A shader may contain only some coordinate patches after staging stops.
// Repair each operation independently before accepting its completion marker.
fn gg_repair_patches(canvas string, name string) ! {
	all := json.parse($embed_file('gg_patches.json').to_string())!.as_map()
	for operation in (all[name] or { json.Null{} }).as_array() {
		row := operation.as_map()
		path := join(canvas, (row['file'] or { json.Null{} }).str())
		replacement := (row['new'] or { json.Null{} }).str()
		source := read(path)!
		if source.contains(replacement) { continue }
		write_changed(path, replace_once(source, (row['old'] or { json.Null{} }).str(), replacement)!)!
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
	}
	if !read(layer)!.contains('document_linear_filter') { gg_patches(canvas, 'prepare_gg_image')! }
	image_helper := read(join(root_dir(), 'tools/ui2/gg_document_image.v'))!
	if image_helper.contains('struct DocumentImageColorTransform') && !read(layer)!.contains('color_transform') {
		gg_patches(canvas, 'prepare_gg_gamma')!
	}
	if image_helper.contains('yuv_rec601_limited') && !read(layer)!.contains('document_image_yuv_upload_supported') {
		gg_patches(canvas, 'prepare_gg_yuv')!
	}
    if image_helper.contains('yuv420_atlas') {
        if !read(layer)!.contains('out << if u.color_transform.yuv420_atlas {') {
            gg_patches(canvas, 'prepare_gg_yuv_atlas_uniform')!
        }
        if !read(layer)!.contains('fn document_image_yuv_atlas_upload_supported()') {
            gg_patches(canvas, 'prepare_gg_yuv_atlas_support')!
        }
        if !read(join(canvas, 'shaders/paint_snippets.metal'))!.contains('gammaParameters_7.z > 0.0f') {
            gg_patches(canvas, 'prepare_gg_yuv_atlas_shader')!
        }
    }
    if image_helper.contains('yuv_jpeg_full') {
        if !read(layer)!.contains('u.color_transform.yuv_jpeg_full') {
            gg_patches(canvas, 'prepare_gg_jpeg_uniform')!
        }
        if !read(layer)!.contains('fn document_image_jpeg_upload_supported()') {
            gg_patches(canvas, 'prepare_gg_jpeg_support')!
        }
        if !read(join(canvas, 'shaders/paint_snippets.metal'))!.contains('gammaParameters_7.w > 0.0f') {
            gg_patches(canvas, 'prepare_gg_jpeg_shader')!
        }
    }
	if !read(layer)!.contains('document_opaque bool') { gg_patches(canvas, 'prepare_gg_opaque_layer')! }
	if !read(join(canvas, 'gpu_surface.v'))!.contains('layer.document_opaque') { gg_patches(canvas, 'prepare_gg_opaque_surface')! }
	gg_repair_patches(canvas, 'prepare_gg_yuv_coordinates')!
	gg_repair_patches(canvas, 'prepare_gg_yuv_subset')!
	gg_repair_patches(canvas, 'prepare_gg_yuv_luma_subset')!
	gg_repair_patches(canvas, 'prepare_gg_image_repeat')!
	gg_repair_patches(canvas, 'prepare_gg_image_quad')!
	gg_repair_patches(canvas, 'prepare_gg_srgb_gamut')!
	write_changed(join(canvas, 'vox_document_image.v'), image_helper)!
	write_changed(join(canvas, 'vox_shadow_mask.v'), read(join(root_dir(), 'tools/ui2/gg_shadow_mask.v'))!)!
	write_changed(join(canvas, 'vox_document_clip.v'), read(join(root_dir(), 'tools/ui2/gg_document_clip.v'))!)!
	if os.is_file(join(canvas, 'gpu_context.v')) {
		gg_repair_patches(canvas, 'prepare_gg_windows_canvas')!
		gg_repair_patches(canvas, 'prepare_gg_d3d11_canvas')!
		gg_repair_patches(canvas, 'prepare_gg_gl_msaa_resolve')!
		gg_repair_patches(canvas, 'prepare_gg_gl_image')!
		gg_repair_patches(canvas, 'prepare_gg_document_gradient_hole')!
		gg_repair_patches(canvas, 'prepare_gg_conical_gradient')!
		for name in ['document_surface.v', 'window_gpu_windows.c.v', 'd3d11_canvas_windows.v',
			'd3d11_canvas_rrect_windows.v'] {
			write_changed(join(canvas, 'vox_' + name), read(join(root_dir(), 'tools/ui2/gg_' + name))!)!
		}
	}
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
	// The retired MSAA experiment added an adapter outside the source GG tree.
	// Re-staging restores GpuContext, so retaining that adapter breaks compilation.
	obsolete_msaa := join(canvas, 'vox_document_msaa.v')
	if exists(obsolete_msaa) && !exists(join(source, 'canvas/vox_document_msaa.v')) {
		remove(obsolete_msaa)!
	}
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
				// A .m include selects Objective-C for the generated program.
				// Keep portable C helpers in C on Windows and Linux.
				if !name.contains('darwin') { continue }
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

fn patch_sokol_metal(text string, helper string) !string {
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
	return text[..first] + body.replace_once('_sg_v_mtl_transfer(', '_sg_v_mtl_transfer_separate(') + '\n#include ' + json.encode(real(helper)) + text[last..]
}

fn patch_sokol_metal_shaders(text string, helper string) !string {
	marker := '_SOKOL_PRIVATE id<MTLLibrary> _sg_mtl_library_from_bytecode('
	included := replace_once(text, marker, '#include ' + json.encode(real(helper)) + '\n\n' + marker)!
	pair := '        vs_lib = _sg_mtl_compile_library(desc->vs.source);\n        fs_lib = _sg_mtl_compile_library(desc->fs.source);'
	patched := replace_once(included, pair, '        vox_gg_metal_compile_shader_sources(desc, &vs_lib, &fs_lib);')!
	vertex := '        vs_lib = _sg_mtl_compile_library(desc->vs.source);\n        if (nil == vs_lib) {'
	return replace_once(patched, vertex, '        vs_lib = vox_gg_metal_compile_vertex_source(desc);\n        if (nil == vs_lib) {')
}

fn patch_sokol_metal_pipelines(text string, helper string) !string {
	start := '_SOKOL_PRIVATE sg_resource_state _sg_mtl_create_pipeline('
	end := '_SOKOL_PRIVATE void _sg_mtl_discard_pipeline('
	if text.count(start) != 1 || text.count(end) != 1 {
		return error('Unsupported Sokol Metal pipeline builder')
	}
	first := text.index(start) or { return error('Missing Sokol Metal pipeline builder') }
	last := text.index_after(end, first) or { return error('Missing Sokol Metal pipeline teardown') }
	body := text[first..last]
	render := '    NSError* err = NULL;\n    id<MTLRenderPipelineState> mtl_rps = '
	depth := '    // depth-stencil-state'
	create_depth := '    id<MTLDepthStencilState> mtl_dss = '
	render_start := body.index(render) or { return error('Missing Sokol Metal render pipeline') }
	depth_start := body.index_after(depth, render_start) or { return error('Missing Sokol Metal depth descriptor') }
	depth_end := body.index_after(create_depth, depth_start) or { return error('Missing Sokol Metal depth state') }
	replacement := '#include ' + json.encode(real(helper)) + '\n\n' + body[..render_start] +
		body[depth_start..depth_end] + '    return vox_gg_metal_create_pipeline_states(pip, rp_desc, ds_desc);\n}\n\n'
	init := '_SOKOL_PRIVATE void _sg_init_pipeline('
	mut patched := replace_once(text[..first] + replacement + text[last..], init,
		'#ifndef VOX_GG_METAL_PIPELINE_PENDING\n#define VOX_GG_METAL_PIPELINE_PENDING(pip) false\n#endif\n\n' + init)!
	for separator, count in {'||': 1, ' || ': 2} {
		assertion := '(pip->slot.state == SG_RESOURCESTATE_VALID)${separator}(pip->slot.state == SG_RESOURCESTATE_FAILED)'
		original := 'SOKOL_ASSERT(${assertion});'
		if patched.count(original) != count { return error('Unsupported Sokol pipeline state assertion') }
		patched = patched.replace(original, 'SOKOL_ASSERT(${assertion} || VOX_GG_METAL_PIPELINE_PENDING(pip));')
	}
	return patched
}

fn prepare_sokol(modules string, vlib string) !string {
	d3d11_helper := join(root_dir(), 'native/include/native_gg_d3d11_transfer.h')
	source := join(os.dir(vlib), 'thirdparty/sokol/sokol_gfx.h')
	original := read(join(vlib, 'sokol/c/declaration.c.v'))!
	include := '#include "sokol_gfx.h"'
	if original.count(include) != 1 { return error('Unsupported Sokol native include') }
	mut header := read(source)!
	mut helpers := [d3d11_helper]
	$if macos {
		metal_helper := join(root_dir(), 'native/include/native_gg_metal_transfer.h')
		shader_helper := join(root_dir(), 'native/include/native_gg_metal_shaders.h')
		pipeline_helper := join(root_dir(), 'native/include/native_gg_metal_pipelines.h')
		header = patch_sokol_metal(header, metal_helper)!
		header = patch_sokol_metal_shaders(header, shader_helper)!
		header = patch_sokol_metal_pipelines(header, pipeline_helper)!
		helpers << [metal_helper, shader_helper, pipeline_helper]
	}
	patches := json.parse($embed_file('gg_patches.json').to_string())!.as_map()
	d3d11_patches := patches['prepare_sokol_d3d11_transfers'] or { return error('Missing Sokol D3D11 transfer patches') }
	for operation in d3d11_patches.as_array() {
		row := operation.as_map()
		old := row['old'] or { return error('Missing Sokol D3D11 patch source') }
		replacement := row['new'] or { return error('Missing Sokol D3D11 patch replacement') }
		header = replace_once(header, old.str(), replacement.str())!
	}
	header = replace_once(header, '#include "native_gg_d3d11_transfer.h"',
		'#include ' + json.encode(real(d3d11_helper)))!
	mut helper_hashes := map[string]json.Any{}
	for helper in helpers {
		helper_hashes[helper] = json.Any(digest(helper)!)
	}
	sha := hash(read(@FILE)! + real(vlib) + header + json.encode(helper_hashes) + original)
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
		tmp := temporary(os.dir(root), 'sokol-')!
		defer { remove(tmp) or {} }
		for name, value in outputs { os.write_file(join(tmp, name), value)! }
		write_json(join(tmp, 'manifest.json'), json.Any(map[string]json.Any{
			'source':        real(source)
			'source_sha256': digest(source)!
			'helpers':       helper_hashes
			'sha256':        sha
		}))!
		os.rename(tmp, root)!
	}
	os.utime(root, time.now().unix(), time.now().unix())!
	link_files(join(modules, 'sokol/c'), join(vlib, 'sokol/c'))!
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
	prepare_sokol(target, vlib)!
	$if macos {
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
