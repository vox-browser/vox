module buildtools

import os

fn vox_canvas_layer_fixture() string {
	return 'module canvas\n' + '\n' + 'pub struct Texture {\n' + '\tmode           f32\n' +
		'\ttexture_height int\n' + '}\n' + '\n' + 'pub struct Binding {\n' + '\timage gfx.Image\n' +
		'}\n' + '\n' + 'fn same(a Texture, b Texture) bool {\n' + '\treturn a.mode == b.mode\n' +
		'}\n' + '\n' + 'fn same_image(a Binding, b Binding) bool {\n' +
		'\treturn a.image.id == b.image.id\n' + '}\n' + '\n' + 'fn emit(u Uniform) {\n' +
		'\tout << u.mode\n' + '\tout << 0\n' + '\tout << 0\n' + '\tout << 0\n' + '}\n' + '\n' +
		'const image_uniform_size = 48\n'
}

fn vox_canvas_surface_fixture() string {
	return 'module canvas\n' + '\n' + 'fn make() {\n' +
		'\t\t\tinv_dimensions: [f32(1) / f32(layer.texture_width), f32(1) / f32(layer.texture_height)]!\n' +
		'\t\t\tupper2x2:       [f32(1), 0, 0, 1]!\n' + '\t\t\timage: layer.image\n' +
		'\tbindings.fs.samplers[0] = ctx.layer_sampler()\n' + '}\n'
}

fn vox_canvas_snippets_fixture() string {
	return 'float mode_6;\n// @@ vertex_image\n// @@ main_image\nfloat4 outColor_1 = _10_sk_csxform_prealpha;\n'
}

fn vox_canvas_gradient_fixture() string {
	return "module canvas\n" + "\n" + "fn build(snippets map[string]string) string {\n" +
		"\tbodies_tile := (snippets['bodies_tile'] + snippets['body_colorize_\${stops}']).replace('_skTemp', 'x')\n" +
		"\treturn bodies_tile\n" + "}\n"
}

fn test_linux_staging_restores_vox_canvas() ! {
	$if windows {
		// Nested module staging uses POSIX-style relative paths; Linux CI
		// covers this regression there.
		return
	}
	root := temporary(os.temp_dir(), 'vox-canvas-staging-')!
	defer { remove(root) or {} }
	source := join(join(root, 'vlib'), 'gg')
	canvas_source := join(source, 'canvas')
	mkdir(canvas_source)!
	os.write_file(join(canvas_source, 'gpu_layer.v'), vox_canvas_layer_fixture())!
	os.write_file(join(canvas_source, 'gpu_surface.v'), vox_canvas_surface_fixture())!
	os.write_file(join(canvas_source, 'gpu_gradient.v'), vox_canvas_gradient_fixture())!
	modules := join(root, 'modules')
	stage_linux_module(source, join(modules, 'gg'), 'gg')!
	canvas := join(modules, 'gg/canvas')
	assert !os.exists(join(canvas, 'vox_document_image.v'))
	assert !read(join(canvas, 'gpu_layer.v'))!.contains('mask_color')
	// Linux staging links the shader asset; seed it where the platform
	// cannot create the link.
	metal := join(canvas, 'shaders/paint_snippets.metal')
	if !os.exists(metal) {
		mkdir(join(canvas, 'shaders'))!
		os.write_file(metal, vox_canvas_snippets_fixture())!
	}
	prepare_gg_gradient_tile(canvas)!
	prepare_gg_canvas(canvas)!
	layer := read(join(canvas, 'gpu_layer.v'))!
	assert layer.contains('mask_color')
	assert layer.contains('document_linear_filter')
	assert layer.contains('color_transform')
	assert os.exists(join(canvas, 'vox_document_image.v'))
	assert os.exists(join(canvas, 'vox_shadow_mask.v'))
	assert read(join(canvas, 'gpu_gradient.v'))!.contains('tile_source :=')
	prepare_gg_gradient_tile(canvas)!
	prepare_gg_canvas(canvas)!
	assert read(join(canvas, 'gpu_layer.v'))! == layer
}
