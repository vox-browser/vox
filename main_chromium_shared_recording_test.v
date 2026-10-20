module main

import layout
import painting

fn shared_recording_test_commands() []layout.PaintCommand {
	return [layout.PaintCommand{ kind: 'fill_rect' }, layout.PaintCommand{
		kind:       'draw_replaced_image'
		image_data: &layout.PaintImageData{ image_url: 'https://example.test/vector.svg?version=2' }
	}]
}

fn test_shared_recording_requires_supported_contiguous_root_drawing_with_vectors() {
	commands := shared_recording_test_commands()
	plan := layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{}]
		command_layers: [0, 0]
	}
	assert chromium_shared_recording_supported(commands, plan)
	assert !chromium_shared_recording_supported([commands[0]], layout.ChromiumRasterLayerPlan{
		layers:         plan.layers
		command_layers: [0]
	})
	assert !chromium_shared_recording_supported(commands, layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{ legacy_raster: true }]
		command_layers: [0, 0]
	})
	assert !chromium_shared_recording_supported([commands[0], commands[0], commands[1]], layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{}, layout.ChromiumRasterLayer{}]
		command_layers: [0, 1, 0]
	})
}

fn test_shared_recording_keeps_clips_effects_and_unrepresented_draws_on_the_leaf_path() {
	base := shared_recording_test_commands()
	plan := layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{}]
		command_layers: [0, 0]
	}
	for unsupported in [
		layout.PaintCommand{ kind: 'begin_css_effect_layer' },
		layout.PaintCommand{ kind: 'draw_text', blur: 1 },
		layout.PaintCommand{ kind: 'fill_rect', has_clip: true, clip_width: 1, clip_height: 1 },
		layout.PaintCommand{ kind: 'fill_rect', clip_outs: [f64(0), 0, 10, 10] },
	] {
		assert !chromium_shared_recording_supported([unsupported, base[1]], plan)
	}
}

fn test_shared_recording_accepts_vector_image_display_lists_but_rejects_nested_documents() {
	image := layout.PaintCommand{
		kind:                      'paint_nested_display_list'
		width:                     80
		height:                    86
		nested_viewport_paintable: &painting.NavigableContainerViewportPaintable{
			viewport_rect: painting.Rect{0, 0, 80, 86}
		}
		nested_viewport_commands:  [layout.PaintCommand{
			kind:     'draw_svg_path'
			svg_data: &layout.PaintSVGPathData{ path_data: [f32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0,
				0, 0] }
		}]
	}
	plan := layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{}]
		command_layers: [0]
	}
	assert chromium_shared_recording_supported([image], plan)
	assert !chromium_shared_recording_supported([layout.PaintCommand{
		...image
		nested_viewport_commands: [layout.PaintCommand{ kind: 'draw_text' }]
	}], plan)
}

fn test_shared_recording_ignores_empty_clipped_leaves_but_keeps_effect_boundaries() {
	base := shared_recording_test_commands()
	plan := layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{}]
		command_layers: [0, 0, 0]
	}
	for kind in ['fill_rect', 'stroke_rounded_rect'] {
		for size in [[f64(0), 1]!, [f64(1), 0]!, [f64(-1), 1]!] {
			hidden := layout.PaintCommand{
				kind:        kind
				has_clip:    true
				clip_width:  size[0]
				clip_height: size[1]
				clip_list:   &layout.PaintClipList{items: [layout.PaintClip{}]}
			}
			assert chromium_shared_recording_supported([base[0], hidden, base[1]], plan)
		}
	}
	for kind in ['begin_css_effect_layer', 'end_css_effect_layer', 'begin_svg_mask_layer'] {
		assert !chromium_shared_recording_supported([base[0], layout.PaintCommand{
			kind:     kind
			has_clip: true
		}, base[1]], plan)
	}
	assert !chromium_shared_recording_supported([layout.PaintCommand{
		...base[1]
		has_clip: true
	}], layout.ChromiumRasterLayerPlan{
		layers:         plan.layers
		command_layers: [0]
	})
}
