// vtest build: macos
module main

import html
import layout
import os

fn test_shadowed_png_pair_requires_adjacent_same_owner_root_paints() {
	mut document := html.parse_document(os.read_file('${@VMODROOT}/Tests/Browser/Brave/diagnostic/shadowed-elliptical-avatar.html')!)
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := root.paint_commands()
	layers := []int{len: commands.len}
	mut index := -1
	for i, c in commands {
		if c.kind == 'paint_outer_box_shadow' {
			index = i
			break
		}
	}
	assert index >= 0
	assert shadowed_png_group_eligible(commands, layers, index)
	for replacement in [layout.PaintCommand{ ...commands[index], blur: 1 },
		layout.PaintCommand{ ...commands[index], has_clip: true },
		layout.PaintCommand{ ...commands[index], opacity: .5 },
		layout.PaintCommand{ ...commands[index], transform: [f64(1), 0, 0, 1, 1, 0]! }] {
		mut altered := commands.clone()
		altered[index] = replacement
		assert !shadowed_png_group_eligible(altered, layers, index)
	}
	mut separate := layers.clone()
	separate[index + 1] = 1
	assert !shadowed_png_group_eligible(commands, separate, index)
	assert !shadowed_png_group_eligible(commands, [], index)
	assert !shadowed_png_group_eligible(commands, layers, commands.len - 1)
}
