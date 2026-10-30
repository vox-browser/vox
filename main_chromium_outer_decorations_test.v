module main

import html
import layout
import math

fn outer_decoration_commands(shadows string, background string) []layout.PaintCommand {
	mut document := html.parse_document('<!doctype html><style>body{margin:0;background:#172233}.ring{position:absolute;left:80.25px;top:130.03125px;width:600px;height:280px;border:1px solid #a6c6f415;border-radius:50%;transform:rotate(-24deg);background:${background};box-shadow:${shadows}}</style><div class="ring"></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	return layout.display_list_commands(document.record_display_list() or { panic('missing paint') })
}

fn test_outer_decorations_retain_one_box_shadow_stack_and_border() {
	for shadows in ['0 -1px #a6c6f40d', '0 -15px 60px #79a8f309,0 -1px #a6c6f40d'] {
		commands := outer_decoration_commands(shadows, 'transparent')
		layers := []int{len: commands.len}
		mut start := -1
		for i, command in commands {
			if command.kind == 'paint_outer_box_shadow' { start = i; break }
		}
		assert start >= 0
		end := chromium_outer_decoration_end(commands, layers, start)
		assert end > start
		assert commands[end - 1].kind == 'paint_uniform_border'
		assert end - start == if shadows.contains(',') { 3 } else { 2 }
		assert chromium_outer_decoration_end(commands, []int{}, start) == start
		assert chromium_outer_decoration_end(commands, layers, -1) == -1
		assert chromium_outer_decoration_end(commands, layers, commands.len) == commands.len
		mut separate := layers.clone()
		separate[end - 1] = 1
		assert chromium_outer_decoration_end(commands, separate, start) == start
		assert chromium_outer_decoration_end(commands[..end - 1], layers[..end - 1], start) == start
	}
}

fn test_outer_decorations_preserve_background_and_effect_boundaries() {
	commands := outer_decoration_commands('0 -15px 60px #79a8f309', '#101722')
	layers := []int{len: commands.len}
	for index, command in commands {
		if command.kind == 'paint_outer_box_shadow' {
			assert chromium_outer_decoration_end(commands, layers, index) == index
		}
	}
	mut eight := []string{}
	for i in 0 .. 8 { eight << '0 ${i + 1}px 4px #79a8f309' }
	for count in [8, 9] {
		shadows := if count == 8 { eight.join(',') } else { eight.join(',') + ',0 10px #0004' }
		stack := outer_decoration_commands(shadows, 'transparent')
		owners := []int{len: stack.len}
		mut start := -1
		for i, command in stack {
			if command.kind == 'paint_outer_box_shadow' { start = i; break }
		}
		assert start >= 0
		end := chromium_outer_decoration_end(stack, owners, start)
		assert (end > start) == (count == 8)
	}
}

fn test_outer_decorations_reject_invalid_or_incompatible_leaves() {
	commands := outer_decoration_commands('0 -15px 60px #79a8f309,0 -1px #a6c6f40d', 'transparent')
	layers := []int{len: commands.len}
	mut start := -1
	for i, command in commands {
		if command.kind == 'paint_outer_box_shadow' { start = i; break }
	}
	assert start >= 0
	for replacement in [
		layout.PaintCommand{ ...commands[start], opacity: 0.5 },
		layout.PaintCommand{ ...commands[start], box_shadow_data: unsafe { nil } },
		layout.PaintCommand{ ...commands[start], kind: 'begin_css_effect_layer' },
		layout.PaintCommand{ ...commands[start], width: 0 },
		layout.PaintCommand{ ...commands[start], blur: math.inf(1) },
		layout.PaintCommand{ ...commands[start], blur: -1 },
		layout.PaintCommand{ ...commands[start], transform: [f64(1), 0, 0, 1, math.nan(), 0]! },
		layout.PaintCommand{ ...commands[start], clip_outs: [f64(0), 0, 10, 10] },
	] {
		mut changed := commands.clone()
		changed[start] = replacement
		assert chromium_outer_decoration_end(changed, layers, start) == start
	}
	mut changed := commands.clone()
	changed[start + 1] = layout.PaintCommand{ ...commands[start + 1], transform: [f64(1), 0, 0, 1, 1, 0]! }
	assert chromium_outer_decoration_end(changed, layers, start) == start
}
