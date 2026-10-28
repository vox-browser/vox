module main

import layout

fn rect_prefetch_test_leaf() layout.PaintCommand {
	return layout.PaintCommand{
		kind:             'fill_rect'
		antialiased_rect: true
		width:            65.8125
		height:           1
		color:            '#000080'
	}
}

fn test_rect_prefetch_scans_text_without_skipping_replay_boundaries() {
	leaf := rect_prefetch_test_leaf()
	text := layout.PaintCommand{ kind: 'draw_text' }
	assert chromium_rect_prefetch_end([leaf, text, text, leaf, text, leaf], [], 0) == 6
	for kind in ['begin_css_effect_layer', 'end_css_effect_layer', 'begin_svg_mask_layer',
		'end_svg_mask_layer', 'begin_skia_command_group', 'end_skia_command_group',
		'draw_background_image', 'draw_svg_path', 'fill_rounded_rect'] {
		commands := [leaf, text, leaf, layout.PaintCommand{ kind: kind }, leaf]
		assert chromium_rect_prefetch_end(commands, [], 0) == 3
	}
	assert chromium_rect_prefetch_end([leaf, text, leaf], [0, 0, 1], 0) == 0
	assert chromium_rect_prefetch_end([leaf, text, leaf], [0], 0) == 0
	assert chromium_rect_prefetch_end([leaf, text, leaf], [], -1) == -1
	assert chromium_rect_prefetch_end([], [], 0) == 0
	assert chromium_rect_prefetch_end([leaf], [], 1) == 1
}

fn test_rect_prefetch_rejects_underlays_effects_and_ineligible_geometry() {
	leaf := rect_prefetch_test_leaf()
	for barrier in [
		layout.PaintCommand{ ...leaf, underlays_next: true },
		layout.PaintCommand{ ...leaf, outer_shadow: true },
		layout.PaintCommand{ ...leaf, disable_antialias: true },
		layout.PaintCommand{ ...leaf, antialiased_rect: false },
		layout.PaintCommand{ ...leaf, radius: 1 },
		layout.PaintCommand{ ...leaf, width: 0 },
		layout.PaintCommand{ ...leaf, width: 1025 },
		layout.PaintCommand{ ...leaf, height: 0 },
		layout.PaintCommand{ ...leaf, height: 4 },
		layout.PaintCommand{ ...leaf, opacity: 0.5 },
		layout.PaintCommand{ ...leaf, group_opacity: 0.5 },
		layout.PaintCommand{ ...leaf, scrollbar_axis: 'vertical' },
		layout.PaintCommand{ ...leaf, clip_outs: [f64(0), 0, 1, 1] },
	] {
		assert chromium_rect_prefetch_end([leaf, barrier, leaf], [], 0) == 0
		assert !chromium_rect_prefetch_leaf(&barrier)
	}
}

fn test_rect_prefetch_bounds_scan_and_shape_counts() {
	leaf := rect_prefetch_test_leaf()
	mut commands := []layout.PaintCommand{len: 80, init: leaf}
	assert chromium_rect_prefetch_end(commands, [], 0) == 16
	for index in 1 .. commands.len {
		if index % 3 != 0 { commands[index] = layout.PaintCommand{ kind: 'draw_text' } }
	}
	assert chromium_rect_prefetch_end(commands, [], 0) == 46
	for index in 2 .. commands.len { commands[index] = layout.PaintCommand{ kind: 'draw_text' } }
	commands[1] = leaf
	assert chromium_rect_prefetch_end(commands, [], 0) == 48
}
