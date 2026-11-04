module main

import html
import layout

fn inset_decoration_commands(shadows string) []layout.PaintCommand {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}div{position:absolute;left:48px;top:43.03125px;width:300px;height:130px;border:1px solid #344151;background:#101722;border-radius:13px;box-shadow:${shadows}}</style><div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	return layout.display_list_commands(document.record_display_list() or { panic('missing paint') })
}

fn test_inset_decoration_groups_retain_background_shadow_and_border_order() {
	for shadows in ['inset 0 1px #ffffff08',
		'0 24px 60px #0004,inset 0 1px #ffffff08',
		'inset 0 1px #ffffff08,inset -3px -4px 7px 2px #79a8f37f'] {
		commands := inset_decoration_commands(shadows)
		layers := []int{len: commands.len}
		mut groups := 0
		for i, command in commands {
			end := chromium_inset_decoration_end(commands, layers, i)
			if end == i { continue }
			groups++
			assert command.kind in ['fill_rect', 'fill_rounded_rect']
			assert commands[end - 1].kind == 'paint_uniform_border'
			assert end - i == if shadows.starts_with('inset 0') && shadows.contains(',') { 4 } else { 3 }
		}
		assert groups == 1
	}
}

fn test_inset_decoration_groups_reject_incomplete_or_incompatible_sequences() {
	commands := inset_decoration_commands('inset 0 1px #ffffff08')
	layers := []int{len: commands.len}
	mut start := -1
	for i in 0 .. commands.len {
		if chromium_inset_decoration_end(commands, layers, i) > i { start = i }
	}
	assert start >= 0
	assert chromium_inset_decoration_end(commands, []int{}, start) == start
	assert chromium_inset_decoration_end(commands[..start + 2], layers[..start + 2], start) == start
	mut separate := layers.clone()
	separate[start + 1] = 1
	assert chromium_inset_decoration_end(commands, separate, start) == start
	for replacement in [
		layout.PaintCommand{ ...commands[start + 1], opacity: 0.5 },
		layout.PaintCommand{ ...commands[start + 1], box_shadow_data: unsafe { nil } },
		layout.PaintCommand{ ...commands[start + 1], kind: 'paint_outer_box_shadow' },
		layout.PaintCommand{ ...commands[start + 1], transform: [f64(1), 0, 0, 1, 1, 0]! },
		layout.PaintCommand{ ...commands[start + 1], clip_outs: [f64(0), 0, 10, 10] },
	] {
		mut changed := commands.clone()
		changed[start + 1] = replacement
		assert chromium_inset_decoration_end(changed, layers, start) == start
	}
}

fn test_inset_decoration_bounds_use_the_scroll_already_in_the_transform() {
	// Viewport-only recording folds the root scroll into the transform.
	scrolled := layout.PaintCommand{
		kind:      'fill_rect'
		x:         32
		y:         302
		width:     960
		height:    220
		transform: [f64(1), 0, 0, 1, 0, -100]!
	}
	left, top, width, height := chromium_inset_decoration_bounds(&scrolled, 112)
	assert left == 32
	assert top == 112 + 302 - 100
	assert width == 960
	// The whole box stays inside the group at every scroll offset.
	assert height == 220
}
