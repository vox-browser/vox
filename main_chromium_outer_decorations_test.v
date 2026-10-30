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

fn test_outer_decorations_retain_overlapping_sibling_boxes_without_crossing_boundaries() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0;background:#172233}.scene{position:absolute;left:49px;top:164.03125px;width:702px;height:438px;overflow:hidden;border-radius:12px}.ring{position:absolute;left:142px;top:158px;width:600px;height:280px;border:1px solid #a6c6f415;border-radius:50%;transform:rotate(-24deg);box-shadow:0 -15px 60px #79a8f309,0 -1px #a6c6f40d}.media{position:absolute;left:113px;top:40px;width:476px;height:320px;border:1px solid #394655;border-radius:7px;box-shadow:0 20px 50px #0005}</style><div class="scene"><div class="ring"></div><div class="media"></div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	commands := layout.display_list_commands(document.record_display_list() or { panic('missing paint') })
	layers := []int{len: commands.len}
	mut start := -1
	for i, command in commands {
		if command.kind == 'paint_outer_box_shadow' { start = i; break }
	}
	assert start >= 0
	first_end := chromium_outer_decoration_end(commands, layers, start)
	assert first_end == start + 3
	assert commands[first_end].kind == 'paint_outer_box_shadow'
	end := chromium_outer_decoration_run_end(commands, layers, start)
	assert end == first_end + 2
	assert !commands[first_end].shares_paint_box_with(unsafe { &commands[start] })
	assert commands[first_end].transform != commands[start].transform
	assert chromium_outer_decoration_run_end(commands, []int{}, start) == start
	// Positive stacking levels can paint after offscreen siblings from an
	// earlier phase. Use exactly the ordinary replay culling rules for the gap.
	gap := [
		layout.PaintCommand{kind: 'fill_rect', x: 0, y: 10000, width: 10, height: 10},
		layout.PaintCommand{kind: 'begin_css_effect_layer', has_clip: true,
			clip_x: 0, clip_y: 10000, clip_width: 10, clip_height: 10},
		layout.PaintCommand{kind: 'begin_css_filter_layer'},
		layout.PaintCommand{kind: 'draw_replaced_image'},
		layout.PaintCommand{kind: 'end_css_filter_layer'},
		layout.PaintCommand{kind: 'end_css_effect_layer'},
	]
	mut separated := commands[..first_end].clone()
	separated << gap
	separated << commands[first_end..]
	separated_layers := []int{len: separated.len}
	assert chromium_outer_decoration_visible_run_end(separated, separated_layers, start,
		PaintCanvasCulling{enabled: true}, 0, 800, 600) == end + gap.len
	assert chromium_outer_decoration_run_end(separated, separated_layers, start) == first_end
	assert chromium_outer_decoration_visible_run_end(separated, separated_layers, start,
		PaintCanvasCulling{enabled: true, depth: 1, resource_depth: 1}, 0, 800, 600) == first_end
	mut visible := separated.clone()
	visible[first_end] = layout.PaintCommand{kind: 'fill_rect', x: 20, y: 20, width: 10, height: 10}
	assert chromium_outer_decoration_visible_run_end(visible, separated_layers, start,
		PaintCanvasCulling{enabled: true}, 0, 800, 600) == first_end
	mut replay := PaintCanvasCulling{enabled: true}
	mut kept := 0
	for i in start .. end + gap.len {
		if !replay.skip(unsafe { &separated[i] }, 0, 0, 800, 600) { kept++ }
	}
	assert kept == end - start
	assert replay.depth == 0 && replay.resource_depth == 0 && replay.skipped_depth == 0
	for kind in ['fill_rect', 'draw_svg_path'] {
		mut edge_gap := commands[..first_end].clone()
		edge_gap << layout.PaintCommand{kind: kind, x: 20, y: 603, width: 20, height: 20}
		edge_gap << commands[first_end..]
		assert chromium_outer_decoration_visible_run_end(edge_gap, []int{len: edge_gap.len},
			start, PaintCanvasCulling{enabled: true}, 0, 800, 600) == end + 1
		edge_gap[first_end] = layout.PaintCommand{kind: kind, x: 20, y: 600, width: 20, height: 20}
		assert chromium_outer_decoration_visible_run_end(edge_gap, []int{len: edge_gap.len},
			start, PaintCanvasCulling{enabled: true}, 0, 800, 600) == first_end
	}
	mut separate := layers.clone()
	separate[first_end] = 1
	assert chromium_outer_decoration_run_end(commands, separate, start) == first_end
	for kind in ['begin_css_effect_layer', 'fill_rect', 'draw_image', 'end_clip'] {
		mut changed := commands.clone()
		changed[first_end] = layout.PaintCommand{ ...commands[first_end], kind: kind }
		assert chromium_outer_decoration_run_end(changed, layers, start) == first_end
	}
	// A long sibling run is split only between complete shadow/border pairs.
	mut repeated := []layout.PaintCommand{}
	for _ in 0 .. 20 { repeated << commands[first_end .. end] }
	assert chromium_outer_decoration_run_end(repeated, []int{len: repeated.len}, 0) == 32
}
