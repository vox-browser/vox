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

fn test_background_clip_effect_scope_includes_masks_around_rounded_svg_images() {
	// A CSS mask isolates coincident clips into separate paint stages.
	mut depth := background_clip_effect_depth_after_command(0, 'begin_svg_mask_layer')
	assert depth == 1
	depth = background_clip_effect_depth_after_command(depth, 'draw_background_image')
	assert depth == 1
	depth = background_clip_effect_depth_after_command(depth, 'begin_css_filter_layer')
	depth = background_clip_effect_depth_after_command(depth, 'begin_svg_mask_layer')
	assert depth == 3
	depth = background_clip_effect_depth_after_command(depth, 'end_svg_mask_layer')
	depth = background_clip_effect_depth_after_command(depth, 'end_css_filter_layer')
	assert depth == 1
	depth = background_clip_effect_depth_after_command(depth, 'end_svg_mask_layer')
	assert depth == 0
	assert background_clip_effect_depth_after_command(depth, 'end_svg_mask_layer') == 0
}

fn test_rounded_svg_background_isolates_only_a_single_mask_effect() {
	mut depth := background_svg_mask_depth_after_command(0, 'begin_svg_mask_layer')
	assert depth == 1 && rounded_svg_background_effects_supported(1, depth)
	depth = background_svg_mask_depth_after_command(depth, 'begin_css_filter_layer')
	assert depth == 1 && !rounded_svg_background_effects_supported(2, depth)
	depth = background_svg_mask_depth_after_command(depth, 'begin_svg_mask_layer')
	assert depth == 2 && !rounded_svg_background_effects_supported(2, depth)
	depth = background_svg_mask_depth_after_command(depth, 'end_svg_mask_layer')
	assert depth == 1
	depth = background_svg_mask_depth_after_command(depth, 'end_svg_mask_layer')
	assert depth == 0 && rounded_svg_background_effects_supported(0, depth)
	assert !rounded_svg_background_effects_supported(1, depth)
	assert background_svg_mask_depth_after_command(depth, 'end_svg_mask_layer') == 0
}
