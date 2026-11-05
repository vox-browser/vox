module main

import layout

fn image_compositor_test_plan() layout.ChromiumRasterLayerPlan {
	return layout.ChromiumRasterLayerPlan{
		layers: [layout.ChromiumRasterLayer{}, layout.ChromiumRasterLayer{
			composited_contents: true
			command_indices: [1, 2, 3]
		}]
		command_layers: [0, 1, 1, 1, 0]
	}
}

fn image_compositor_test_commands() []layout.PaintCommand {
	return [layout.PaintCommand{kind:'fill_rect'},
		layout.PaintCommand{kind:'draw_replaced_image',width:100,height:80},
		layout.PaintCommand{kind:'fill_rect',color:'rgba(40,70,90,.2)',width:20,height:20},
		layout.PaintCommand{kind:'draw_replaced_image',x:40,width:100,height:80},
		layout.PaintCommand{kind:'fill_rect'}]
}

fn test_image_only_promoted_picture_keeps_its_transparent_compositor_surface() {
	commands := image_compositor_test_commands()
	plan := image_compositor_test_plan()
	assert chromium_svg_compositor_layer_supported(commands,plan,1)
	// A picture with only images still has a compositor boundary, including
	// when no glyphs, gradients or vector paths happen to be visible.
	mut images_only := commands.clone()
	images_only[2] = commands[1]
	assert chromium_svg_compositor_layer_supported(images_only,plan,1)
	mut solid_only := commands.clone()
	solid_only[1] = commands[2]
	solid_only[3] = commands[2]
	assert !chromium_svg_compositor_layer_supported(solid_only,plan,1)
}

fn test_image_picture_preserves_existing_effect_and_recording_exclusions() {
	commands := image_compositor_test_commands()
	plan := image_compositor_test_plan()
	for replacement in [layout.PaintCommand{kind:'begin_svg_mask_layer'},
		layout.PaintCommand{kind:'begin_css_filter_layer'},
		layout.PaintCommand{...commands[1],opacity:.5},
		layout.PaintCommand{...commands[1],group_opacity:.5},
		layout.PaintCommand{...commands[1],blur:1}] {
		mut unsupported := commands.clone()
		unsupported[1] = replacement
		assert !chromium_svg_compositor_layer_supported(unsupported,plan,1)
	}
	mut ordinary := image_compositor_test_plan()
	ordinary.layers[1].composited_contents = false
	assert !chromium_svg_compositor_layer_supported(commands,ordinary,1)
	ordinary.layers[1].composited_contents = true
	ordinary.layers[1].legacy_raster = true
	assert !chromium_svg_compositor_layer_supported(commands,ordinary,1)
}

fn test_image_picture_does_not_cross_an_interleaved_layer_without_metadata() {
	commands := image_compositor_test_commands()
	mut plan := image_compositor_test_plan()
	plan.layers[1].command_indices = [1,3]
	plan.command_layers[2] = 0
	assert !chromium_svg_compositor_layer_supported(commands,plan,1)
	plan.command_layers[2] = -1
	assert chromium_svg_compositor_layer_supported(commands,plan,1)
}
