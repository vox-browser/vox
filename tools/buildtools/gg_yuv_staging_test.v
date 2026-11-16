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
	os.write_file(layer, '// mask_color document_linear_filter color_transform\n\tdocument_scale [2]f32 = [f32(1),1]!\nconst image_uniform_size = 112\n\tout << u.color_transform.gamma\n\tout << 0\n\tout << 0\n\tout << 0\n')!
	coordinates := patches['prepare_gg_yuv_coordinates']!.as_array()
	vertex := coordinates[0].as_map()['old']!.str()
	os.write_file(shader, vertex + '\n' + 'float4 _10_mask = sample(_globals.image_4, _in.CoordNormalize_3_Var);\n')!
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
		os.write_file(path, read(path)!.replace_once(staged_new, operation['old']!.str()))!
		prepare_gg_canvas(canvas)!
		assert read(layer)! == first_layer
		assert read(shader)! == first_shader
		assert read(surface)! == first_surface
	}
	for coordinate in coordinates {
		row := coordinate.as_map()
		os.write_file(shader, read(shader)!.replace_once(row['new']!.str(), row['old']!.str()))!
		prepare_gg_canvas(canvas)!
		assert read(shader)! == first_shader
		assert read(layer)! == first_layer
	}
}
