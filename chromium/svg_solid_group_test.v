module main

import layout
import painting
import css

fn scaled_svg_viewport_command() layout.PaintCommand {
	return layout.PaintCommand{
		kind:      'draw_svg_path'
		color:     'white'
		transform: [f64(1), 0, 0, 1, 33, 422]!
		svg_data:  &layout.PaintSVGPathData{
			path_transform: [f64(.04), 0, 0, .04, 0, 10.5]!
			path_data:      [f32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 400, 70, 0, 0, 0, 0, 0,
				0, 0, 0, 0]
		}
	}
}

fn test_downscaled_svg_batch_viewport_keeps_the_last_covered_pixel_row() {
	command := scaled_svg_viewport_command()
	bounds := chromium_msaa_trigger_rect(&command) or { panic('bounds') }
	assert bounds.y + bounds.height > 435.25 && bounds.y + bounds.height < 435.5
	viewport := chromium_svg_solid_run_viewport([command, command], 0, 2) or { panic('viewport') }
	assert viewport.y == 432 && viewport.y + viewport.height == 436
	assert viewport.x == 32 && viewport.x + viewport.width == 50
}

fn test_svg_batch_enclosure_preserves_fractional_author_clip_boundaries() {
	command := layout.PaintCommand{
		...scaled_svg_viewport_command()
		has_clip:    true
		clip_x:      33.25
		clip_y:      432.875
		clip_width:  10.5
		clip_height: 2.375
	}
	viewport := chromium_svg_solid_run_viewport([command, command], 0, 2) or { panic('viewport') }
	assert viewport == layout.LayoutRect{33.25, 432.875, 10.5, 2.375}
	assert chromium_svg_solid_run_viewport([], 0, 0) == none
}

fn svg_solid_group_test_command() layout.PaintCommand {
	return layout.PaintCommand{
		kind:     'draw_svg_path'
		color:    '#ecae63'
		svg_data: &layout.PaintSVGPathData{
			path_data: [f32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
		}
	}
}

fn test_solid_svg_runs_preserve_mask_and_effect_boundaries() {
	fill := svg_solid_group_test_command()
	for kind in ['begin_svg_mask_layer', 'end_svg_mask_layer', 'begin_css_effect_layer',
		'end_css_effect_layer', 'begin_skia_command_group', 'end_skia_command_group'] {
		commands := [fill, fill, layout.PaintCommand{ kind: kind }, fill, fill]
		assert chromium_svg_solid_run_end(commands, [], 0) == 2
		assert chromium_svg_solid_run_end(commands, [], 2) == 2
		assert chromium_svg_solid_run_end(commands, [], 3) == 5
	}
	assert chromium_svg_solid_run_end([fill], [], 0) == 0
	assert chromium_svg_solid_run_end([], [], 0) == 0
	assert chromium_svg_solid_run_end([fill, fill], [], -1) == -1
	assert chromium_svg_solid_run_end([fill, fill], [], 2) == 2
}

fn test_solid_svg_runs_accept_equivalent_mapped_rectangular_clips() {
	fill := svg_solid_group_test_command()
	clip := layout.PaintClip{ rect: layout.LayoutRect{5, 6, 60, 45} }
	first := layout.PaintCommand{
		...fill
		has_clip:    true
		clip_x:      5
		clip_y:      6
		clip_width:  60
		clip_height: 45
		clip_list:   &layout.PaintClipList{ items: [clip] }
	}
	second := layout.PaintCommand{
		...first
		clip_list: &layout.PaintClipList{ items: [clip] }
	}
	// Nested viewport replay allocates separate lists for the same clip.
	assert voidptr(first.clip_list) != voidptr(second.clip_list)
	assert chromium_svg_solid_run_end([first, second], [], 0) == 2
	for different in [
		layout.PaintCommand{ ...second, clip_width: 50 },
		layout.PaintCommand{ ...second, has_clip: false },
	] {
		assert chromium_svg_solid_run_end([first, different], [], 0) == 0
	}
}

fn test_single_svg_paint_opacity_uses_the_float_recording_without_crossing_a_barrier() {
	base := svg_solid_group_test_command()
	for opacity in [0.0, 0.3, 0.5, 0.75] {
		fill := layout.PaintCommand{
			...base
			svg_data: &layout.PaintSVGPathData{
				...base.svg_data
				fill_opacity: opacity
			}
		}
		stroke := layout.PaintCommand{
			...base
			color:        ''
			stroke_color: '#348dc7'
			stroke_width: 2
			svg_data:     &layout.PaintSVGPathData{
				stroke_opacity: opacity
				path_data:      [f32(0), 0, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 14, 0, 0, 0, 0, 0,
					0, 0, 0, 0, 0]
			}
		}
		for command in [fill, stroke] {
			assert chromium_svg_solid_run_end([command], [], 0) == 1
			commands := [command, layout.PaintCommand{ kind: 'end_svg_mask_layer' }, base]
			assert chromium_svg_solid_run_end(commands, [], 0) == 1
			assert chromium_svg_solid_run_end(commands, [], 1) == 1
			assert chromium_svg_solid_run_end([command, base], [1, 2], 0) == 1
			assert chromium_svg_solid_run_end([layout.PaintCommand{ ...command, opacity: .5 }], [], 0) == 0
			assert chromium_svg_solid_run_end([layout.PaintCommand{ ...command, group_opacity: .5 }], [], 0) == 0
		}
	}
}

fn test_single_svg_color_alpha_selects_the_float_recording() {
	base := svg_solid_group_test_command()
	serialized := 'rgba(236, 174, 99, 0.5882352941)'
	fill := layout.PaintCommand{
		...base
		color:    serialized
		svg_data: &layout.PaintSVGPathData{
			...base.svg_data
			svg_solid_color_data: &layout.PaintSVGSolidColorData{
				fill_serialized: serialized
				fill:            css.Color{236, 174, 99, 150}
				has_fill:        true
				fill_alpha:      0.59
				has_fill_alpha:  true
			}
		}
	}
	assert chromium_svg_solid_run_end([fill], [], 0) == 1
	assert chromium_svg_solid_paint_alpha(&fill, false, 150) == 0.59
	changed := layout.PaintCommand{ ...fill, color: 'red' }
	assert chromium_svg_solid_run_end([changed], [], 0) == 0
	assert chromium_svg_solid_paint_alpha(&changed, false, 255) == 1
	assert chromium_svg_solid_run_end([fill, layout.PaintCommand{ kind: 'end_svg_mask_layer' },
		base], [], 0) == 1
	assert chromium_svg_solid_run_end([fill, base], [0, 1], 0) == 1
}

fn test_solid_svg_runs_reject_clips_that_need_individual_replay() {
	fill := svg_solid_group_test_command()
	for clip in [
		layout.PaintClip{ is_path: true },
		layout.PaintClip{ is_svg_mask: true },
		layout.PaintClip{ is_svg_content_mask: true },
		layout.PaintClip{ corner_radii: layout.BoxRadii{ top_left: layout.CornerRadius{2, 2} } },
		layout.PaintClip{ transform: [f64(1), 0.5, 0, 1, 0, 0]! },
		layout.PaintClip{ transform: [f64(1), 0, 0.5, 1, 0, 0]! },
	] {
		clipped := layout.PaintCommand{
			...fill
			has_clip:    true
			clip_width:  80
			clip_height: 60
			clip_list:   &layout.PaintClipList{ items: [clip] }
		}
		assert chromium_svg_solid_run_end([clipped, clipped], [], 0) == 0
	}
}

fn test_solid_svg_runs_reject_combined_fill_stroke_gradients_and_flattened_opacity() {
	fill := svg_solid_group_test_command()
	gradient := layout.PaintCommand{
		...fill
		svg_data: &layout.PaintSVGPathData{
			...fill.svg_data
			svg_gradient_data: &layout.PaintSVGGradientData{
				fill_linear_gradient: painting.SVGLinearGradientPaintStyle{}
			}
		}
	}
	for barrier in [
		layout.PaintCommand{ ...fill, stroke_color: '#000', stroke_width: 1 },
		layout.PaintCommand{ ...fill, opacity: 0.5 },
		layout.PaintCommand{ ...fill, group_opacity: 0.5 },
		layout.PaintCommand{ ...fill, clip_outs: [f64(0), 0, 10, 10] },
		layout.PaintCommand{ ...fill, color: '' },
		gradient,
	] {
		assert chromium_svg_solid_run_end([fill, fill, barrier, fill], [], 0) == 2
		assert chromium_svg_solid_run_end([barrier, barrier], [], 0) == 0
	}
}

fn test_solid_svg_runs_share_translucent_resize_grip_strokes() {
	fill := svg_solid_group_test_command()
	dark := layout.PaintCommand{
		...fill
		color:        ''
		stroke_color: 'rgba(0, 0, 0, 0.6)'
		stroke_width: 2
		svg_data:     &layout.PaintSVGPathData{
			path_data: [f32(0), 0, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 14, 0, 0, 0, 0, 0, 0, 0, 0,
				0, 0]
		}
	}
	light := layout.PaintCommand{ ...dark, stroke_color: 'rgba(255, 255, 255, 0.6)' }
	assert chromium_svg_solid_run_end([dark, light], [], 0) == 2
	assert chromium_svg_solid_run_end([fill, dark, light], [], 0) == 3
	mut joined := dark.svg_data.path_data.clone()
	joined << [f32(1), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	mut curve := dark.svg_data.path_data.clone()
	curve[layout.compatibility_clip_path_segment_stride] = 2
	for barrier in [
		layout.PaintCommand{ ...dark, stroke_width: 0 },
		layout.PaintCommand{ ...dark, stroke_width: -1 },
		layout.PaintCommand{
			...dark
			svg_data: &layout.PaintSVGPathData{
				...dark.svg_data
				stroke_dasharray: [
					2.0,
					1.0,
				]
			}
		},
		layout.PaintCommand{
			...dark
			svg_data: &layout.PaintSVGPathData{ ...dark.svg_data, non_scaling_stroke: true }
		},
		layout.PaintCommand{
			...dark
			svg_data: &layout.PaintSVGPathData{ ...dark.svg_data, stroke_linecap: 2 }
		},
		layout.PaintCommand{
			...dark
			svg_data: &layout.PaintSVGPathData{ ...dark.svg_data, path_data: joined }
		},
		layout.PaintCommand{
			...dark
			svg_data: &layout.PaintSVGPathData{ ...dark.svg_data, path_data: curve }
		},
	] {
		assert chromium_svg_solid_run_end([barrier, barrier], [], 0) == 0
		assert chromium_svg_solid_run_end([dark, light, barrier], [], 0) == 2
	}
}

fn test_solid_svg_runs_preserve_root_raster_layers() {
	fill := svg_solid_group_test_command()
	assert chromium_svg_solid_run_end([fill, fill, fill], [0, 0, 1], 0) == 2
	assert chromium_svg_solid_run_end([fill, fill], [0, 1], 0) == 0
	assert chromium_svg_solid_run_end([fill, fill], [0], 0) == 0
}

fn test_precise_svg_leaf_paints_keep_channels_and_combine_opacity_once() {
	base := svg_solid_group_test_command()
	command := layout.PaintCommand{
		...base
		color:        'gray'
		stroke_color: 'blue'
		svg_data:     &layout.PaintSVGPathData{
			...base.svg_data
			svg_solid_color_data: &layout.PaintSVGSolidColorData{
				fill_serialized:   'gray'
				stroke_serialized: 'blue'
				fill_srgb:         &layout.PaintSRGBColor{'gray', [f64(.23), .25, .27, 1]!}
				stroke_srgb:       &layout.PaintSRGBColor{'blue', [f64(20.25 / 255), 40.5 / 255,
					60.75 / 255, .5]!}
				has_fill:          true
				has_stroke:        true
			}
		}
	}
	assert chromium_svg_precise_paint(&command, false, .4)? == [f32(.23), .25, .27, .4]!
	assert chromium_svg_precise_paint(&command, true, .6)? == [f32(20.25 / 255), f32(40.5 / 255),
		f32(60.75 / 255), .3]!
	mut changed := command
	changed.color = 'red'
	assert chromium_svg_precise_paint(&changed, false, .4) == none
	assert chromium_svg_precise_paint(&changed, true, .6) == chromium_svg_precise_paint(&command, true, .6)
	// RGB precision alone must keep an isolated opaque leaf on its existing
	// geometry path, including scaled SVG viewports.
	leaf := layout.PaintCommand{ ...command, stroke_color: '' }
	assert chromium_svg_solid_run_end([leaf], [], 0) == 0
}

fn test_solid_svg_batch_can_omit_a_rounded_ancestor_that_cannot_touch_its_ink() {
	fill := svg_solid_group_test_command()
	clip := layout.PaintClip{
		rect:         layout.LayoutRect{-100, -100, 500, 500}
		corner_radii: layout.BoxRadii{ top_left: layout.CornerRadius{100, 100} }
	}
	command := layout.PaintCommand{ ...fill, has_clip: true, clip_x: -100, clip_y: -100, clip_width: 500, clip_height: 500, clip_list: &layout.PaintClipList{ items: [clip] } }
	assert chromium_svg_solid_run_end([command, command], [], 0) == 2
	corner := layout.PaintClip{ ...clip, rect: layout.LayoutRect{0, 0, 30, 30}, corner_radii: layout.BoxRadii{ top_left: layout.CornerRadius{20, 20} } }
	clipped := layout.PaintCommand{ ...command, clip_list: &layout.PaintClipList{ items: [corner] } }
	assert chromium_svg_solid_run_end([clipped, clipped], [], 0) == 0
}
