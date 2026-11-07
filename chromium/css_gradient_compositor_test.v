module main

import css
import html
import layout
import math
import os

fn css_compositor_gradient() layout.PaintCommand {
	return layout.PaintCommand{
		kind:                      'fill_gradient'
		width:                     120
		height:                    140
		gradient_background_layer: true
		gradient:                  &layout.LinearGradient{
			kind:  'linear'
			x2:    1
			y2:    1
			stops: [layout.GradientStop{css.Color{18, 27, 40, 143}, 0},
				layout.GradientStop{css.Color{16, 21, 30, 143}, 1}]
		}
		image_data:                &layout.PaintImageData{ image_clip_width: 120, image_clip_height: 140 }
	}
}

fn css_compositor_scope_plan(count int) layout.ChromiumRasterLayerPlan {
	return layout.ChromiumRasterLayerPlan{
		has_paint_metadata: true
		layers:             [layout.ChromiumRasterLayer{}, layout.ChromiumRasterLayer{
			composited_contents: true
			command_indices:     []int{len: count, init: index}
		}]
		command_layers:     []int{len: count, init: 1}
	}
}

fn test_css_gradient_records_inside_a_complete_compositor_scope() {
	layer := &layout.PaintVisualLayer{ kind: .css_effect, scope_id: 7 }
	commands := [
		layout.PaintCommand{ kind: 'begin_css_effect_layer', visual_layer_data: layer },
		layout.PaintCommand{ kind: 'fill_rect', color: '#111925' },
		css_compositor_gradient(),
		layout.PaintCommand{ kind: 'end_css_effect_layer', visual_layer_data: layer },
	]
	assert chromium_shared_recording_layer_supported(commands, css_compositor_scope_plan(commands.len), 1)
	// Ordinary root gradients keep their existing leaf policy.
	assert !chromium_shared_recording_supported([commands[1], commands[2]],
		layout.ChromiumRasterLayerPlan{
			layers:         [layout.ChromiumRasterLayer{}]
			command_layers: [
				0,
				0,
			]
		})
}

fn test_css_gradient_isolates_a_contiguous_scrolling_compositor_picture() {
	commands := [css_compositor_gradient(), layout.PaintCommand{ kind: 'draw_text', text: 'gradient' }]
	assert chromium_svg_compositor_layer_supported(commands, css_compositor_scope_plan(commands.len), 1)
	mut ordinary := css_compositor_scope_plan(commands.len)
	ordinary.layers[1].composited_contents = false
	assert !chromium_svg_compositor_layer_supported(commands, ordinary, 1)
	mut gap := css_compositor_scope_plan(commands.len)
	gap.layers[1].command_indices = [0]
	assert !chromium_svg_compositor_layer_supported(commands, gap, 1)
}

fn test_css_gradient_picture_keeps_supported_ellipse_and_stroke_leaves() {
	for kind in ['fill_ellipse', 'stroke_ellipse', 'stroke_rounded_rect'] {
		commands := [css_compositor_gradient(), layout.PaintCommand{
			kind:   kind
			x:      10
			y:      10
			width:  20
			height: 20
			color:  '#abc'
		}]
		assert chromium_svg_compositor_layer_supported(commands, css_compositor_scope_plan(commands.len), 1)
	}
}

fn test_css_gradient_picture_can_cross_a_gap_only_when_every_command_is_culled() {
	commands := [css_compositor_gradient(),
		layout.PaintCommand{ kind: 'unrepresented_offscreen_draw' },
		layout.PaintCommand{ kind: 'draw_text', text: 'gradient' }]
	mut plan := css_compositor_scope_plan(commands.len)
	plan.layers[1].command_indices = [0, 2]
	plan.command_layers = [1, -1, 1]
	assert chromium_svg_compositor_layer_supported(commands, plan, 1)
	plan.command_layers[1] = 0
	assert !chromium_svg_compositor_layer_supported(commands, plan, 1)
}

fn test_css_gradient_picture_can_ignore_only_an_offscreen_scroll_layer() {
	commands := [css_compositor_gradient(), layout.PaintCommand{ kind: 'draw_text', text: 'child' },
		layout.PaintCommand{ kind: 'draw_text', text: 'parent' }]
	mut plan := layout.ChromiumRasterLayerPlan{
		has_paint_metadata: true
		layers:             [layout.ChromiumRasterLayer{}, layout.ChromiumRasterLayer{
			composited_contents: true
			command_indices:     [0, 2]
		}, layout.ChromiumRasterLayer{
			scroll_contents: true
			command_indices: [1]
			bounds:          layout.LayoutRect{0, 9000, 800, 100}
		}]
		command_layers:     [1, 2, 1]
	}
	assert !chromium_svg_compositor_layer_supported(commands, plan, 1)
	assert chromium_svg_compositor_layer_supported_for_viewport(commands, plan, 1, layout.LayoutRect{0, 6400, 1280, 800})
	assert !chromium_svg_compositor_layer_supported_for_viewport(commands, plan, 1, layout.LayoutRect{0, 8900, 1280, 800})
	plan.layers[2].scroll_contents = false
	assert !chromium_svg_compositor_layer_supported_for_viewport(commands, plan, 1, layout.LayoutRect{0, 6400, 1280, 800})
}

fn test_css_gradient_picture_uses_actual_culled_ink_for_an_interleaved_background() {
	mut commands := [css_compositor_gradient(), layout.PaintCommand{
		kind:      'fill_rounded_rect'
		x:         20
		y:         9000
		width:     200
		height:    100
		transform: [f64(1), 0, 0, 1, 0, -6400]!
	}, layout.PaintCommand{ kind: 'draw_text', text: 'parent' }]
	mut plan := css_compositor_scope_plan(commands.len)
	plan.layers[1].command_indices = [0, 2]
	plan.layers << layout.ChromiumRasterLayer{
		composited_contents: true
		command_indices:     [1]
		bounds:              layout.LayoutRect{0, 0, 1280, 12000}
	}
	plan.command_layers = [1, 2, 1]
	assert !chromium_svg_compositor_layer_supported(commands, plan, 1)
	assert chromium_svg_compositor_layer_supported_for_viewport(commands, plan, 1, layout.LayoutRect{0, 6400, 1280, 800})
	commands[1].y = 6500
	assert !chromium_svg_compositor_layer_supported_for_viewport(commands, plan, 1, layout.LayoutRect{0, 6400, 1280, 800})
}

fn test_complete_css_gradient_pictures_keep_supported_raster_images_in_the_same_surface() {
	image := layout.PaintCommand{
		kind:       'draw_replaced_image'
		image_data: &layout.PaintImageData{ image_url: 'https://images.test/photo.png' }
	}
	commands := [css_compositor_gradient(), image]
	plan := css_compositor_scope_plan(commands.len)
	assert chromium_svg_compositor_layer_supported(commands, plan, 1)
	assert !chromium_svg_compositor_layer_supported([commands[0],
		layout.PaintCommand{ ...image, opacity: .5 }], plan, 1)
	svg_background := layout.PaintCommand{
		kind:       'draw_background_image'
		image_data: &layout.PaintImageData{ image_url: 'https://images.test/pattern.svg' }
	}
	assert !chromium_svg_compositor_layer_supported([commands[0], svg_background], plan, 1)
}

fn test_compositor_gradients_reject_unrepresented_geometry_and_color_spaces() {
	base := css_compositor_gradient()
	gradient := base.gradient?
	layer := &layout.PaintVisualLayer{ kind: .css_effect, scope_id: 7 }
	for index, rejected in [
		layout.PaintCommand{ ...base, gradient: none },
		layout.PaintCommand{ ...base, gradient_background_layer: false },
		layout.PaintCommand{ ...base, image_data: unsafe { nil } },
		layout.PaintCommand{ ...base, image_data: &layout.PaintImageData{ image_clip_width: math.nan(), image_clip_height: 140 } },
		layout.PaintCommand{ ...base, image_data: &layout.PaintImageData{ image_clip_width: 120 } },
		layout.PaintCommand{
			...base
			image_data: &layout.PaintImageData{
				image_clip_width:      120
				image_clip_height:     140
				background_blend_mode: .multiply
			}
		},
		layout.PaintCommand{ ...base, blur: 1 },
		layout.PaintCommand{ ...base, outer_shadow: true },
		layout.PaintCommand{ ...base, clip_outs: [f64(0), 0, 12, 12] },
		layout.PaintCommand{
			...base
			has_clip:    true
			clip_width:  120
			clip_height: 140
			clip_list:   &layout.PaintClipList{ items: [layout.PaintClip{ is_path: true }] }
		},
		layout.PaintCommand{
			...base
			gradient: &layout.LinearGradient{
				...gradient
				interpolation_method: css.RectangularColorSpace.oklab
			}
		},
		layout.PaintCommand{ ...base, gradient: &layout.LinearGradient{ ...gradient, x2: 0, y2: 0 } },
		layout.PaintCommand{
			...base
			gradient: &layout.LinearGradient{
				...gradient
				stops: [layout.GradientStop{css.Color{255, 0, 0, 64}, 0},
					layout.GradientStop{css.Color{0, 0, 255, 255}, 1}]
			}
		},
	] {
		commands := [
			layout.PaintCommand{ kind: 'begin_css_effect_layer', visual_layer_data: layer },
			rejected,
			layout.PaintCommand{ kind: 'end_css_effect_layer', visual_layer_data: layer },
		]
		assert !chromium_shared_recording_layer_supported(commands, css_compositor_scope_plan(commands.len), 1), 'case ${index}'
		assert !chromium_svg_compositor_layer_supported([rejected], css_compositor_scope_plan(1), 1)
	}
}

fn test_real_promoted_and_scrolling_css_gradients_keep_complete_picture_ownership() {
	mut document := html.parse_document(os.read_file('${@VMODROOT}/Tests/Browser/Brave/input/compositor-css-gradients.html')!)
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := layout.display_list_commands(document.record_display_list() or { panic('missing paint') })
	for scale in [1.0, 2.0] {
		mut plan := layout.ChromiumRasterLayerPlan{}
		layout.update_chromium_raster_layer_plan_for_viewport(document, commands, scale,
			layout.LayoutRect{0, 0, 1024, 768}, mut plan)
		mut gradients := 0
		mut owners := map[int]bool{}
		for index, command in commands {
			if command.kind != 'fill_gradient' { continue }
			gradients++
			owner := plan.command_layers[index]
			assert owner > 0
			owners[owner] = true
			supported := chromium_shared_recording_layer_supported(commands, plan, owner)
				|| chromium_svg_compositor_layer_supported(commands, plan, owner)
			assert supported == (scale == 1)
		}
		assert gradients >= 6
		assert owners.len >= 2
	}
}
