// vtest build: macos
module main

import layout
import math

fn test_contoured_sequence_keeps_one_owner_and_balanced_background_border() {
	data := &layout.PaintLocalBorderData{ corner_shapes: [f64(1.1), 1.1, 1.1, 1.1]! }
	shadow := layout.PaintCommand{ kind: 'paint_outer_box_shadow', width: 700, height: 52, blur: 16, local_border_data: data, box_shadow_data: &layout.PaintBoxShadowData{} }
	background := layout.PaintCommand{ kind: 'fill_rect', width: 698, height: 50, radius: 25, underlays_next: true, local_border_data: data }
	border := layout.PaintCommand{ kind: 'paint_uniform_border', width: 699, height: 51, stroke_width: 1, local_border_data: data }
	commands := [shadow, shadow, background, border]
	assert contoured_group_end(commands, [2, 2, 2, 2], 0) == 4
	assert contoured_group_end(commands, [2, 3, 2, 2], 0) == 0
	assert contoured_group_end(commands[..3], [2, 2, 2], 0) == 0
	for invalid in [layout.PaintCommand{ ...shadow, blur: math.inf(1) },
		layout.PaintCommand{ ...shadow, box_shadow_data: unsafe { nil } },
		layout.PaintCommand{ ...shadow, clip_outs: [f64(0), 0, 10, 10] }] {
		mut changed := commands.clone()
		changed[1] = invalid
		assert contoured_group_end(changed, [2, 2, 2, 2], 0) == 0
	}
	mut interrupted := commands.clone()
	interrupted[2] = layout.PaintCommand{ ...background, kind: 'draw_text' }
	assert contoured_group_end(interrupted, [2, 2, 2, 2], 0) == 0
}
