// vtest build: macos
module main

import html
import layout

fn test_rounded_background_group_rejects_independent_clip_and_sample_state() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}div{position:absolute;left:50px;top:50px;width:217px;height:52px;box-sizing:border-box;border:1px solid #528fd4;background:#467fc2;border-radius:10px 0 0 10px}</style><div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	commands := layout.display_list_commands(document.record_display_list() or { panic('paint') })
	layers := []int{len: commands.len}
	mut pairs := 0
	for i, c in commands {
		if c.kind != 'fill_rounded_rect' || c.color != 'rgb(70 127 194)' { continue }
		assert rounded_background_group_end(commands, layers, i) == i + 2
		pairs++
		for replacement in [layout.PaintCommand{ ...commands[i + 1], has_clip: true },
			layout.PaintCommand{ ...commands[i + 1], disable_antialias: true },
			layout.PaintCommand{ ...commands[i + 1], group_opacity: .5 },
			layout.PaintCommand{ ...commands[i + 1], clip_outs: [f64(0), 0, 10, 10] },
			layout.PaintCommand{ ...commands[i + 1], scrollbar_axis: 'vertical' }] {
			mut changed := commands.clone()
			changed[i + 1] = replacement
			assert rounded_background_group_end(changed, layers, i) == i
		}
		mut separate := layers.clone()
		separate[i + 1] = 1
		assert rounded_background_group_end(commands, separate, i) == i
	}
	assert pairs == 1
	assert rounded_background_group_end(commands, layers, -1) == -1
	assert rounded_background_group_end(commands, layers, commands.len) == commands.len
}
