module main

import html
import layout
import math

fn test_rounded_background_pair_preserves_individual_corner_shapes() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}div{position:absolute;top:50px;width:217px;height:52px;box-sizing:border-box;border:1px solid #528fd4;background:#467fc2}.left{left:50px;border-radius:10px 0 0 10px}.right{left:280px;border-radius:0 10px 10px 0}.round{left:510px;border-radius:10px}</style><div class="left"></div><div class="right"></div><div class="round"></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	commands := layout.display_list_commands(document.record_display_list() or { panic('missing paint') })
	layers := []int{len: commands.len}
	mut pairs := 0
	for i, command in commands {
		if command.kind !in ['fill_rect', 'fill_rounded_rect'] || command.color != 'rgb(70 127 194)' { continue }
		assert chromium_rounded_background_pair_end(commands, layers, i) == i + 2
		pairs++
		mut separate := layers.clone()
		separate[i + 1] = 1
		assert chromium_rounded_background_pair_end(commands, separate, i) == i
		for replacement in [
			layout.PaintCommand{ ...commands[i + 1], kind: 'begin_css_filter_layer' },
			layout.PaintCommand{ ...commands[i + 1], opacity: 0.5 },
			layout.PaintCommand{ ...commands[i + 1], x: commands[i + 1].x + 1 },
			layout.PaintCommand{ ...commands[i + 1], stroke_width: math.nan() },
			layout.PaintCommand{ ...commands[i + 1], transform: [f64(1), 0, 0, 1, 1, 0]! },
			layout.PaintCommand{ ...commands[i + 1], clip_outs: [f64(0), 0, 10, 10] },
		] {
			mut changed := commands.clone()
			changed[i + 1] = replacement
			assert chromium_rounded_background_pair_end(changed, layers, i) == i
		}
	}
	assert pairs == 3
	assert chromium_rounded_background_pair_end(commands, []int{}, 0) == 0
	assert chromium_rounded_background_pair_end(commands, layers, -1) == -1
	assert chromium_rounded_background_pair_end(commands, layers, commands.len) == commands.len
}
