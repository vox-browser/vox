module main

import layout
import math
import css

fn test_compositor_shadow_rejection_includes_the_native_blur_margin_and_fringe() {
	viewport := layout.LayoutRect{0, 0, 1024, 768}
	shadow := layout.PaintCommand{ kind: 'paint_outer_box_shadow', x: 688, y: 3749, width: 304, height: 171, blur: 20 }
	assert chromium_compositor_leaf_is_culled(&shadow, viewport)
	for y in [f64(700), 800, 811] {
		near := layout.PaintCommand{ ...shadow, y: y }
		assert !chromium_compositor_leaf_is_culled(&near, viewport)
	}
	for changed in [layout.PaintCommand{ ...shadow, blur: math.nan() },
		layout.PaintCommand{ ...shadow, blur: math.inf(1) },
		layout.PaintCommand{ ...shadow, transform: [f64(1), 0, 0, 1, 0, -3749]! },
		layout.PaintCommand{ ...shadow, transform: [f64(1), 0, 0, 1, 0, 1e8]! },
		layout.PaintCommand{ ...shadow, kind: 'begin_css_filter_layer' }] {
		assert !chromium_compositor_leaf_is_culled(&changed, viewport)
	}
}

fn test_compositor_shadow_culling_retains_inner_bounds_and_empty_clip_scopes() {
	viewport := layout.LayoutRect{0, 0, 1024, 768}
	shadow := layout.PaintCommand{
		kind:            'paint_inner_box_shadow'
		y:               4000
		width:           100
		height:          20
		box_shadow_data: &layout.PaintBoxShadowData{ content_rect: layout.LayoutRect{0, 100, 100, 20} }
	}
	assert !chromium_compositor_leaf_is_culled(&shadow, viewport)
	for kind in ['fill_rect', 'paint_outer_box_shadow'] {
		leaf := layout.PaintCommand{ kind: kind, has_clip: true, clip_width: 0, clip_height: 10 }
		assert chromium_compositor_leaf_is_culled(&leaf, viewport)
	}
	boundary := layout.PaintCommand{ kind: 'begin_svg_mask_layer', has_clip: true, clip_width: 0, clip_height: 10 }
	assert !chromium_compositor_leaf_is_culled(&boundary, viewport)
}

fn test_completed_parent_prefix_keeps_unknown_child_filters_in_their_original_order() {
	filter := &layout.PaintVisualLayer{ kind: .css_filter, scope_id: 44 }
	commands := [layout.PaintCommand{ kind: 'fill_rect' },
		layout.PaintCommand{ kind: 'fill_rect', y: 10, width: 100, height: 20 },
		layout.PaintCommand{ kind: 'begin_css_filter_layer', visual_layer_data: filter },
		layout.PaintCommand{ kind: 'draw_canvas' },
		layout.PaintCommand{ kind: 'end_css_filter_layer', visual_layer_data: filter },
		layout.PaintCommand{ kind: 'fill_rect', y: 4000, width: 100, height: 20 }]
	plan := layout.ChromiumRasterLayerPlan{
		has_paint_metadata: true
		layers:             [layout.ChromiumRasterLayer{ command_indices: [0] },
			layout.ChromiumRasterLayer{ composited_contents: true, command_indices: [1, 5] },
			layout.ChromiumRasterLayer{ legacy_raster: true, command_indices: [2, 3, 4] }]
		command_layers:     [0, 1, 2, 2, 2, 1]
	}
	viewport := layout.LayoutRect{0, 0, 1024, 768}
	assert chromium_compositor_gap_can_flush_parent(commands, plan, 1, 2, 5, viewport)
	mut changed := commands.clone()
	changed[5] = layout.PaintCommand{ ...commands[5], y: 10 }
	assert !chromium_compositor_gap_can_flush_parent(changed, plan, 1, 2, 5, viewport)
	changed = commands.clone()
	changed[4] = layout.PaintCommand{ kind: 'end_svg_mask_layer', visual_layer_data: filter }
	assert !chromium_compositor_gap_can_flush_parent(changed, plan, 1, 2, 5, viewport)
}

fn test_culled_unsupported_background_does_not_disable_visible_gradient_picture() {
	gradient := layout.PaintCommand{
		kind:                      'fill_gradient'
		width:                     56
		height:                    23
		gradient_background_layer: true
		image_data:                &layout.PaintImageData{ image_clip_width: 56, image_clip_height: 23 }
		gradient:                  &layout.LinearGradient{
			kind:  'linear'
			x2:    1
			stops: [
				layout.GradientStop{css.Color{255, 255, 255, 255}, 0},
				layout.GradientStop{css.Color{255, 255, 255, 0}, 1},
			]
		}
	}
	background := layout.PaintCommand{
		kind:       'draw_background_image'
		y:          4000
		width:      100
		height:     20
		image_data: &layout.PaintImageData{
			image_url:         'https://example.test/unloaded.svg'
			image_clip_y:      4000
			image_clip_width:  100
			image_clip_height: 20
		}
	}
	commands := [gradient, background]
	plan := layout.ChromiumRasterLayerPlan{
		has_paint_metadata: true
		layers:             [layout.ChromiumRasterLayer{}, layout.ChromiumRasterLayer{
			composited_contents: true
			command_indices:     [0, 1]
		}]
		command_layers:     [1, 1]
	}
	viewport := layout.LayoutRect{0, 0, 1024, 768}
	assert !chromium_svg_compositor_layer_supported(commands, plan, 1)
	assert chromium_compositor_leaf_is_culled(&background, viewport)
	assert chromium_svg_compositor_layer_supported_for_viewport(commands, plan, 1, viewport)
	moved := layout.PaintCommand{ ...background, transform: [f64(1), 0, 0, 1, 0, -4000]! }
	assert !chromium_compositor_leaf_is_culled(&moved, viewport)
	assert !chromium_svg_compositor_layer_supported_for_viewport([gradient, moved], plan, 1, viewport)
}

fn test_culling_the_last_vector_retains_a_promoted_text_surface() {
	gradient := layout.PaintCommand{
		kind: 'fill_gradient'
		y: 4000
		width: 100
		height: 20
		gradient_background_layer: true
		image_data: &layout.PaintImageData{image_clip_y: 4000, image_clip_width: 100, image_clip_height: 20}
		gradient: &layout.LinearGradient{
			kind: 'linear'
			x2: 1
			stops: [layout.GradientStop{css.Color{255, 255, 255, 255}, 0},
				layout.GradientStop{css.Color{0, 0, 0, 255}, 1}]
		}
	}
	text := layout.PaintCommand{kind: 'draw_text', text: 'Find your people.', width: 100, height: 20}
	commands := [gradient, text]
	plan := layout.ChromiumRasterLayerPlan{
		has_paint_metadata: true
		layers: [layout.ChromiumRasterLayer{}, layout.ChromiumRasterLayer{
			composited_contents: true
			command_indices: [0, 1]
		}]
		command_layers: [1, 1]
	}
	viewport := layout.LayoutRect{0, 0, 800, 600}
	assert !chromium_text_scroll_layer_supported(commands, plan, 1)
	assert chromium_compositor_leaf_is_culled(&gradient, viewport)
	assert chromium_svg_compositor_layer_supported_for_viewport(commands, plan, 1, viewport)
	bad_text := layout.PaintCommand{...text, blur: 1}
	assert !chromium_svg_compositor_layer_supported_for_viewport([gradient, bad_text], plan, 1, viewport)
	no_text := layout.PaintCommand{kind: 'fill_rect', width: 100, height: 20}
	assert !chromium_svg_compositor_layer_supported_for_viewport([gradient, no_text], plan, 1, viewport)
	mut unpromoted := plan
	unpromoted.layers = plan.layers.clone()
	unpromoted.layers[1].composited_contents = false
	assert !chromium_svg_compositor_layer_supported_for_viewport(commands, unpromoted, 1, viewport)
}
