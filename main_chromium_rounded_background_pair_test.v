module main

import html
import layout
import math
import os

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

fn test_partial_border_background_and_child_header_keep_one_resolve() {
	mut document := html.parse_document(os.read_file('${@VMODROOT}/Tests/Browser/Brave/input/chromium-partial-rounded-border.html')!)
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := root.paint_commands()
	layers := []int{len: commands.len}
	mut groups := 0
	for i, command in commands {
		if command.kind != 'fill_rounded_rect' || command.color != 'rgb(230 230 230)' { continue }
		assert chromium_rounded_background_pair_end(commands, layers, i) == i + 3
		groups++
		mut separate := layers.clone()
		separate[i + 2] = 1
		assert chromium_rounded_background_pair_end(commands, separate, i) == i
		for header in [
			layout.PaintCommand{...commands[i + 2], x: commands[i + 2].x + 1},
			layout.PaintCommand{...commands[i + 2], color: 'rgb(76 76 76 / 0.5)'},
			layout.PaintCommand{...commands[i + 2], opacity: 0.5},
			layout.PaintCommand{...commands[i + 2], width: math.nan()},
			layout.PaintCommand{...commands[i + 2], transform: [f64(1), 0, 0, 1, 1, 0]!},
			layout.PaintCommand{...commands[i + 2], clip_outs: [f64(0), 0, 10, 10]},
		] {
			mut changed := commands.clone()
			changed[i + 2] = header
			assert chromium_rounded_background_pair_end(changed, layers, i) == i
		}
		mut shifted := commands.clone()
		shifted[i].x += 0.5
		assert chromium_rounded_background_pair_end(shifted, layers, i) == i
	}
	assert groups == 2
	assert chromium_partial_decoration_end(commands, []int{}, 0) == 0
	assert chromium_partial_decoration_end(commands, layers, -1) == -1
	assert chromium_partial_decoration_end(commands, layers, commands.len - 1) == commands.len - 1
}
