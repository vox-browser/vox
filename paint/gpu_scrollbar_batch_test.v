module main

import layout

fn test_scrollbar_gpu_damage_covers_fill_stroke_and_page_offset() {
	commands := [layout.PaintCommand{kind: 'draw_text', x: 2, y: 3, width: 50, height: 20},
		layout.PaintCommand{kind: 'fill_rounded_rect', x: 390, y: 13, width: 7, height: 140, scrollbar_axis: 'vertical'},
		layout.PaintCommand{kind: 'stroke_rounded_rect', x: 390, y: 13, width: 7, height: 140, stroke_width: 1, scrollbar_axis: 'vertical'}]
	rects := scrollbar_gpu_damage_rects(commands, 0, 112)
	assert rects.len == 4
	assert rects[0] <= 389 && rects[0] + rects[2] >= 398
	assert rects[1] <= 124 && rects[1] + rects[3] >= 266
	assert scrollbar_gpu_damage_rects(commands, commands.len, 112).len == 0
}

fn test_scrollbar_gpu_damage_merges_transitively_and_bounds_native_tiles() {
	mut commands := []layout.PaintCommand{}
	for x in [0, 20, 10] {
		commands << layout.PaintCommand{kind: 'fill_rect', x: x, y: 0, width: 10, height: 10, scrollbar_axis: 'horizontal'}
	}
	assert scrollbar_gpu_damage_rects(commands, 0, 0).len == 4
	commands = []layout.PaintCommand{}
	for index in 0 .. 9 {
		commands << layout.PaintCommand{kind: 'fill_rect', x: index * 100, y: 0, width: 4, height: 4, scrollbar_axis: 'horizontal'}
	}
	assert scrollbar_gpu_damage_rects(commands[..8], 0, 0).len == 32
	assert scrollbar_gpu_damage_rects(commands, 0, 0).len == 0
	assert scrollbar_gpu_damage_rects([layout.PaintCommand{kind: 'draw_text', scrollbar_axis: 'vertical'}], 0, 0).len == 0
}
