module buildtools

import os
import json2 as json

fn test_native_preparer_keeps_yuv_uniform_and_shader_together() ! {
	root := temporary(os.temp_dir(), 'vox-gg-yuv-staging-')!
	defer { remove(root) or {} }
	canvas := join(root, 'canvas')
	mkdir(join(canvas, 'shaders'))!
	layer := join(canvas, 'gpu_layer.v')
	shader := join(canvas, 'shaders/paint_snippets.metal')
	surface := join(canvas, 'gpu_surface.v')
	patches := json.parse($embed_file('gg_patches.json').to_string())!.as_map()
	opaque_surface := patches['prepare_gg_opaque_surface']!.as_array()[0].as_map()
	os.write_file(surface, opaque_surface['old']!.str())!
	os.write_file(layer, '// mask_color document_linear_filter color_transform\n\tdocument_scale [2]f32 = [f32(1),1]!\nconst image_uniform_size = 112\n\t\tfor row in 0 .. 3 { out << u.color_transform.gamut[column * 3 + row] }\n\tout << u.color_transform.gamma\n\tout << 0\n\tout << 0\n\tout << 0\n')!
	coordinates := patches['prepare_gg_yuv_coordinates']!.as_array()
	vertex := coordinates[0].as_map()['old']!.str()
	mut color_source := ''
	// Include optional color-adapter anchors when the shared preparer has
	// them, so this minimal shader remains valid across adapter additions.
	if gamma := patches['prepare_gg_srgb_gamut'] {
		for operation in gamma.as_array() {
			color_source += operation.as_map()['old']!.str() + '\n'
		}
	}
	os.write_file(shader, vertex + '\n' + 'float4 _10_mask = sample(_globals.image_4, _in.CoordNormalize_3_Var);\n' + color_source)!
	// Seed the independent opaque and repeating-image adapters in their real
	// order; this fixture intentionally omits unrelated upstream GPU code.
	for group in ['prepare_gg_opaque_layer', 'prepare_gg_opaque_surface', 'prepare_gg_image_repeat'] {
		for installed in patches[group]!.as_array() {
			row := installed.as_map()
			path := join(canvas, row['file']!.str())
			text := read(path)!
			before, after := row['old']!.str(), row['new']!.str()
			if text.contains(after) { continue }
			os.write_file(path, if text.contains(before) {
				text.replace_once(before, after)
			} else {
				text + '\n' + after
			})!
		}
	}

	prepare_gg_canvas(canvas)!
	first_layer, first_shader := read(layer)!, read(shader)!
	first_surface := read(surface)!
	assert first_layer.contains('document_opaque bool')
	assert first_surface.contains('layer.document_opaque && layer.mask_color.a == 1')
	assert first_layer.contains('u.color_transform.yuv_rec601_limited')
	assert first_layer.contains('fn document_image_yuv_upload_supported()')
	assert first_shader.contains('gammaParameters_7.y > 0.0f')
	assert first_layer.contains('u.color_transform.yuv420_atlas')
	assert first_layer.contains('fn document_image_yuv_atlas_upload_supported()')
	assert first_shader.contains('gammaParameters_7.z > 0.0f')
	assert first_layer.contains('u.color_transform.yuv_jpeg_full')
	assert first_layer.contains('fn document_image_jpeg_upload_supported()')
	assert first_shader.contains('gammaParameters_7.w > 0.0f')
	assert first_shader.contains('float2 documentImageCoords')
	assert first_shader.contains('documentImageCoords * 0.5f')
	assert first_layer.contains('u.color_transform.yuv_chroma_bounds[index]')
	assert first_shader.contains('float4 chromaBounds')
	assert first_shader.contains('float4 lumaBounds')
	assert first_surface.contains('layer.color_transform.image_quad_coords')
	assert read(join(canvas, 'vox_document_image.v'))!.contains('!document_image_yuv_upload_supported()')
	prepare_gg_canvas(canvas)!
	assert read(layer)! == first_layer
	assert read(shader)! == first_shader
	// Repair either new atlas half independently without duplicating the
	// already-installed uniform, capability check or shader branch.
	for group in ['prepare_gg_yuv_atlas_uniform', 'prepare_gg_yuv_atlas_support',
		'prepare_gg_yuv_atlas_shader', 'prepare_gg_jpeg_uniform', 'prepare_gg_jpeg_support',
		'prepare_gg_jpeg_shader', 'prepare_gg_opaque_layer', 'prepare_gg_opaque_surface'] {
		operation := patches[group]!.as_array()[0].as_map()
		path := join(canvas, operation['file']!.str())
		mut staged_new := operation['new']!.str()
		for coordinate in coordinates {
			row := coordinate.as_map()
			staged_new = staged_new.replace(row['old']!.str(), row['new']!.str())
		}
		for repeat in patches['prepare_gg_image_repeat']!.as_array() {
			row := repeat.as_map()
			staged_new = staged_new.replace(row['old']!.str(), row['new']!.str())
		}
		for subset in patches['prepare_gg_yuv_subset']!.as_array() {
			row := subset.as_map()
			staged_new = staged_new.replace(row['old']!.str(), row['new']!.str())
		}
		for luma in patches['prepare_gg_yuv_luma_subset']!.as_array() {
			row := luma.as_map()
			staged_new = staged_new.replace(row['old']!.str(), row['new']!.str())
		}
		os.write_file(path, read(path)!.replace_once(staged_new, operation['old']!.str()))!
		prepare_gg_canvas(canvas)!
		assert read(layer)! == first_layer, group
		assert read(shader)! == first_shader, group
		assert read(surface)! == first_surface
	}
	for coordinate in coordinates {
		row := coordinate.as_map()
		os.write_file(shader, read(shader)!.replace_once(row['new']!.str(), row['old']!.str()))!
		prepare_gg_canvas(canvas)!
		assert read(shader)! == first_shader
		assert read(layer)! == first_layer
	}
	for subset in patches['prepare_gg_yuv_subset']!.as_array() {
		row := subset.as_map()
		path := join(canvas, row['file']!.str())
		os.write_file(path, read(path)!.replace_once(row['new']!.str(), row['old']!.str()))!
		prepare_gg_canvas(canvas)!
		assert read(layer)! == first_layer
		assert read(shader)! == first_shader
	}

	for quad in patches['prepare_gg_image_quad']!.as_array() {
		row := quad.as_map()
		path := join(canvas, row['file']!.str())
		os.write_file(path, read(path)!.replace_once(row['new']!.str(), row['old']!.str()))!
		prepare_gg_canvas(canvas)!
		assert read(surface)! == first_surface
		assert read(layer)! == first_layer
		assert read(shader)! == first_shader
	}

	for luma in patches['prepare_gg_yuv_luma_subset']!.as_array() {
		row := luma.as_map()
		os.write_file(shader, read(shader)!.replace_once(row['new']!.str(), row['old']!.str()))!
		prepare_gg_canvas(canvas)!
		assert read(shader)! == first_shader
		assert read(layer)! == first_layer
	}
}
