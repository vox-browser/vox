module buildtools

import os

fn test_native_preparer_keeps_yuv_uniform_and_shader_together() ! {
	root := temporary(os.temp_dir(), 'vox-gg-yuv-staging-')!
	defer { remove(root) or {} }
	canvas := join(root, 'canvas')
	mkdir(join(canvas, 'shaders'))!
	layer := join(canvas, 'gpu_layer.v')
	shader := join(canvas, 'shaders/paint_snippets.metal')
	os.write_file(layer, '// mask_color document_linear_filter color_transform\nconst image_uniform_size = 112\n\tout << u.color_transform.gamma\n\tout << 0\n')!
	os.write_file(shader, 'float4 _10_mask = sample(_globals.image_4, _in.CoordNormalize_3_Var);\n')!
	prepare_gg_canvas(canvas)!
	first_layer, first_shader := read(layer)!, read(shader)!
	assert first_layer.contains('u.color_transform.yuv_rec601_limited')
	assert first_layer.contains('fn document_image_yuv_upload_supported()')
	assert first_shader.contains('gammaParameters_7.y > 0.0f')
	assert read(join(canvas, 'vox_document_image.v'))!.contains('!document_image_yuv_upload_supported()')
	prepare_gg_canvas(canvas)!
	assert read(layer)! == first_layer
	assert read(shader)! == first_shader
}
