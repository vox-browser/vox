module main

import layout
import math

fn test_svg_sprite_culling_uses_embedding_clip_instead_of_full_sprite_tile() {
	command := layout.PaintCommand{
		kind: 'draw_background_image'
		x: 20
		y: 100
		width: 176
		height: 811
		image_data: &layout.PaintImageData{
			image_clip_x: 20
			image_clip_y: 900
			image_clip_width: 30
			image_clip_height: 30
		}
	}
	assert !background_image_clip_intersects_viewport(&command, 0, 88, 1024, 88, 856, false)
	mut partially_visible := command
	partially_visible.image_data = &layout.PaintImageData{...partially_visible.image(), image_clip_y: 760}
	assert background_image_clip_intersects_viewport(&partially_visible, 0, 88, 1024, 88, 856, false)
	partially_visible.image_data = &layout.PaintImageData{...partially_visible.image(), image_clip_y: 769}
	assert background_image_clip_intersects_viewport(&partially_visible, 0, 88, 1024, 88, 856, false)
}

fn test_background_clip_culling_observes_scroll_and_non_axis_aligned_transforms() {
	mut command := layout.PaintCommand{
		image_data: &layout.PaintImageData{
			image_clip_x: 20
			image_clip_y: 900
			image_clip_width: 30
			image_clip_height: 30
		}
		transform: [f64(1), 0, 0, 1, 0, -300]!
	}
	assert background_image_clip_intersects_viewport(&command, 0, 88, 1024, 88, 856, false)
	command.transform = [f64(0), -1, 1, 0, 0, 1000]!
	assert !background_image_clip_intersects_viewport(&command, 0, 88, 1024, 88, 856, false)
	command.transform = [f64(0), -1, 1, 0, 0, 600]!
	assert background_image_clip_intersects_viewport(&command, 0, 88, 1024, 88, 856, false)
}

fn test_background_clip_culling_retains_effect_inputs_and_unknown_bounds() {
	mut command := layout.PaintCommand{
		image_data: &layout.PaintImageData{
			image_clip_x: 20
			image_clip_y: 900
			image_clip_width: 30
			image_clip_height: 30
		}
		visual_layer_list: &layout.PaintVisualLayerList{}
	}
	assert background_image_clip_intersects_viewport(&command, 0, 88, 1024, 88, 856, false)
	command.visual_layer_list = unsafe { nil }
	command.transform = [f64(1), 0, 0, 1, 0, math.inf(1)]!
	assert background_image_clip_intersects_viewport(&command, 0, 88, 1024, 88, 856, false)
}

fn test_background_clip_culling_keeps_nested_filter_inputs_without_leaf_metadata() {
	command := layout.PaintCommand{
		image_data: &layout.PaintImageData{
			image_clip_x: 20
			image_clip_y: 900
			image_clip_width: 30
			image_clip_height: 30
		}
	}
	mut depth := background_clip_effect_depth_after_command(0, 'begin_css_filter_layer')
	depth = background_clip_effect_depth_after_command(depth, 'begin_skia_command_group')
	assert background_image_clip_intersects_viewport(&command, 0, 88, 1024, 88, 856, depth > 0)
	depth = background_clip_effect_depth_after_command(depth, 'end_skia_command_group')
	assert background_image_clip_intersects_viewport(&command, 0, 88, 1024, 88, 856, depth > 0)
	depth = background_clip_effect_depth_after_command(depth, 'end_css_filter_layer')
	assert !background_image_clip_intersects_viewport(&command, 0, 88, 1024, 88, 856, depth > 0)
}
