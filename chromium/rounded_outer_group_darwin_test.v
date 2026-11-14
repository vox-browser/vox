// vtest build: macos
module main

import html
import layout
import os
import math

fn test_rounded_outer_group_keeps_one_owner_and_rejects_unsafe_replay() {
	mut document := html.parse_document(os.read_file('${@VMODROOT}/Tests/Browser/Brave/input/rounded-opaque-shadow-group.html')!)
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := root.paint_commands()
	layers := []int{len: commands.len}
	mut start := -1
	for i, c in commands {
		if c.kind == 'paint_outer_box_shadow' {
			start = i
			break
		}
	}
	assert start >= 0
	assert rounded_outer_group_end(commands, layers, start) == start + 3
	assert rounded_outer_group_end(commands, []int{}, start) == start
	mut separate := layers.clone()
	separate[start + 1] = 1
	assert rounded_outer_group_end(commands, separate, start) == start
	for replacement in [
		layout.PaintCommand{ ...commands[start + 1], has_clip: true },
		layout.PaintCommand{ ...commands[start + 1], opacity: .5 },
		layout.PaintCommand{ ...commands[start + 1], width: math.nan() },
		layout.PaintCommand{ ...commands[start + 1], x: commands[start + 1].x + 1 },
		layout.PaintCommand{ ...commands[start + 1], underlays_next: true },
	] {
		mut altered := commands.clone()
		altered[start + 1] = replacement
		assert rounded_outer_group_end(altered, layers, start) == start
	}
}
