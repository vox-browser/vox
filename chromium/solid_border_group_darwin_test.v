module main

import html
import layout
import math

fn test_solid_border_group_requires_one_complete_unclipped_border() {
	mut document := html.parse_document($embed_file('@VMODROOT/Tests/Browser/Brave/input/rotated-border-join.html').to_string())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := root.paint_commands()
	mut count := 0
	for i, c in commands {
		if c.local_border_data == unsafe { nil } || c.local_border_data.solid_side_count != 2
			|| (i > 0 && voidptr(commands[i - 1].local_border_data) == voidptr(c.local_border_data)) {
			continue
		}
		count++
		for layer in [0, 1] {
			layers := []int{len: commands.len, init: layer}
			assert solid_border_group_end(commands, layers, i) == i + 2
			assert solid_border_group_end(commands, layers, i + 1) == i + 1
			mut separate := layers.clone()
			separate[i + 1]++
			assert solid_border_group_end(commands, separate, i) == i
			for replacement in [
				layout.PaintCommand{ ...commands[i + 1], opacity: 0.5 },
				layout.PaintCommand{ ...commands[i + 1], group_opacity: 0.5 },
				layout.PaintCommand{ ...commands[i + 1], antialiased_rect: false },
				layout.PaintCommand{ ...commands[i + 1], disable_antialias: true },
				layout.PaintCommand{ ...commands[i + 1], has_clip: true },
				layout.PaintCommand{ ...commands[i + 1], clip_outs: [f64(0), 0, 1, 1] },
				layout.PaintCommand{ ...commands[i + 1], transform: [f64(1), 0, 0, 1, 0, 0]! },
				layout.PaintCommand{ ...commands[i + 1], color: 'red' },
				layout.PaintCommand{ ...commands[i + 1], width: math.nan() },
				layout.PaintCommand{ ...commands[i + 1], local_border_data: &layout.PaintLocalBorderData{ solid_side_count: 2 } },
			] {
				mut changed := commands.clone()
				changed[i + 1] = replacement
				assert solid_border_group_end(changed, layers, i) == i
			}
		}
		assert solid_border_group_end(commands[..i + 1], []int{len: i + 1}, i) == i
	}
	assert count == 2
	assert solid_border_group_end(commands, []int{}, 0) == 0
	assert solid_border_group_end(commands, []int{len: commands.len}, -1) == -1
	assert solid_border_group_end(commands, []int{len: commands.len}, commands.len) == commands.len
}

fn test_solid_border_group_keeps_three_sides_in_painter_order() {
	mut document := html.parse_document('<!doctype html><div style="width:20px;height:20px;border-top:1px solid white;border-right:1px solid white;border-bottom:1px solid white;transform:rotate(45deg)"></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	commands := layout.layout_document_typed_in_viewport(document, 100, 100).paint_commands()
	mut count := 0
	for i, c in commands {
		if c.local_border_data == unsafe { nil } || c.local_border_data.solid_side_count != 3
			|| (i > 0 && voidptr(commands[i - 1].local_border_data) == voidptr(c.local_border_data)) {
			continue
		}
		assert solid_border_group_end(commands, []int{len: commands.len}, i) == i + 3
		assert commands[i].height == 1
		assert commands[i + 1].height == 1
		assert commands[i + 2].width == 1
		count++
	}
	assert count == 1
}
