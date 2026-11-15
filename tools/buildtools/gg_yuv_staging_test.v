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
	os.write_file(layer, '// mask_color document_linear_filter color_transform\nconst image_uniform_size = 112\n\tout << u.color_transform.gamma\n\tout << 0\n\tout << 0\n\tout << 0\n')!
	os.write_file(shader, 'float4 _10_mask = sample(_globals.image_4, _in.CoordNormalize_3_Var);\n')!
	prepare_gg_canvas(canvas)!
	first_layer, first_shader := read(layer)!, read(shader)!
	assert first_layer.contains('u.color_transform.yuv_rec601_limited')
	assert first_layer.contains('fn document_image_yuv_upload_supported()')
	assert first_shader.contains('gammaParameters_7.y > 0.0f')
	assert first_layer.contains('u.color_transform.yuv420_atlas')
	assert first_layer.contains('fn document_image_yuv_atlas_upload_supported()')
	assert first_shader.contains('gammaParameters_7.z > 0.0f')
	assert read(join(canvas, 'vox_document_image.v'))!.contains('!document_image_yuv_upload_supported()')
	prepare_gg_canvas(canvas)!
	assert read(layer)! == first_layer
	assert read(shader)! == first_shader
	// Repair either new atlas half independently without duplicating the
	// already-installed uniform, capability check or shader branch.
	patches := json.parse($embed_file('gg_patches.json').to_string())!.as_map()
	for group in ['prepare_gg_yuv_atlas_uniform', 'prepare_gg_yuv_atlas_support',
		'prepare_gg_yuv_atlas_shader'] {
		operation := patches[group]!.as_array()[0].as_map()
		path := join(canvas, operation['file']!.str())
		os.write_file(path, read(path)!.replace_once(operation['new']!.str(), operation['old']!.str()))!
		prepare_gg_canvas(canvas)!
		assert read(layer)! == first_layer
		assert read(shader)! == first_shader
	}
}
