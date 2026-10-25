module main

import layout
import painting

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

fn test_solid_svg_runs_reject_strokes_gradients_and_flattened_opacity() {
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

fn test_solid_svg_runs_preserve_root_raster_layers() {
	fill := svg_solid_group_test_command()
	assert chromium_svg_solid_run_end([fill, fill, fill], [0, 0, 1], 0) == 2
	assert chromium_svg_solid_run_end([fill, fill], [0, 1], 0) == 0
	assert chromium_svg_solid_run_end([fill, fill], [0], 0) == 0
}
