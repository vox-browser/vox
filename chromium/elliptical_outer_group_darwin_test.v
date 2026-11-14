// vtest build: macos
module main

import html
import layout
import os

fn test_elliptical_outer_group_retains_adjacent_decorations_and_common_rect_clip() {
	for radius in [0, 12] {
		source := os.read_file('${@VMODROOT}/Tests/Browser/Brave/diagnostic/rotated-ellipse-shadow.html')!
		mut document := html.parse_document(source.replace('overflow: hidden;', 'border-radius:${radius}px;overflow: hidden;'))
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
		end := elliptical_outer_group_end(commands, layers, start)
		assert end == start + 3
		for altered_command in [layout.PaintCommand{ ...commands[start], blur: -1 },
			layout.PaintCommand{ ...commands[start], disable_antialias: true },
			layout.PaintCommand{ ...commands[start], transform: [f64(1), 0, 0, 1, 0, 0]! },
			layout.PaintCommand{ ...commands[start], opacity: .5 },
			layout.PaintCommand{ ...commands[start], recording_clip: layout.LayoutRect{0, 0, 100, 100} }] {
			mut altered := commands.clone()
			altered[start] = altered_command
			assert elliptical_outer_group_end(altered, layers, start) == start
		}
		if commands[start].clip_list != unsafe { nil } {
			mut changed := commands.clone()
			changed[start + 1].clip_list = &layout.PaintClipList{ items: commands[start].clip_list.items.clone() }
			assert elliptical_outer_group_end(changed, layers, start) == start
		}
		mut separate := layers.clone()
		separate[start + 1] = 1
		assert elliptical_outer_group_end(commands, separate, start) == start
		assert elliptical_outer_group_end(commands, [], start) == start
	}
}
