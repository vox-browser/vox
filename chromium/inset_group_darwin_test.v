// vtest build: macos
module main

import html
import layout
import math

fn inset_group_commands(shadows string) []layout.PaintCommand {
	mut doc := html.parse_document('<!doctype html><style>body{margin:0}div{position:absolute;left:48px;top:43.03125px;width:300px;height:130px;border:1px solid #344151;background:#101722;border-radius:13px;box-shadow:${shadows}}</style><div></div>')
	defer { doc.finalize() }
	doc.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(doc, 800, 600)
	return layout.display_list_commands(doc.record_display_list() or { panic('paint') })
}

fn test_inset_group_keeps_order_in_a_common_root_or_nonroot_picture() {
	for shadows in ['inset 0 1px #ffffff08', 'inset 0 1px #ffffff08,inset -3px 2px #79a8f37f'] {
		commands := inset_group_commands(shadows)
		for owner in [0, 2] {
			layers := []int{len: commands.len, init: owner}
			mut groups := 0
			for i, c in commands {
				end := inset_group_end(commands, layers, i)
				if end == i { continue }
				groups++
				assert c.kind in ['fill_rect', 'fill_rounded_rect']
				assert commands[end - 1].kind == 'paint_uniform_border'
				assert end - i == if shadows.contains(',') { 4 } else { 3 }
			}
			assert groups == 1
		}
	}
}

fn test_inset_group_preserves_fallback_for_blur_clips_and_independent_state() {
	commands := inset_group_commands('inset 0 1px #ffffff08')
	layers := []int{len: commands.len}
	mut start := -1
	for i in 0 .. commands.len { if inset_group_end(commands, layers, i) > i { start = i } }
	assert start >= 0
	for replacement in [layout.PaintCommand{ ...commands[start + 1], blur: 1 },
		layout.PaintCommand{ ...commands[start + 1], group_opacity: .5 },
		layout.PaintCommand{ ...commands[start + 1], disable_antialias: true },
		layout.PaintCommand{ ...commands[start + 1], has_clip: true },
		layout.PaintCommand{ ...commands[start + 1], clip_list: &layout.PaintClipList{} },
		layout.PaintCommand{ ...commands[start + 1], box_shadow_data: unsafe { nil } },
		layout.PaintCommand{ ...commands[start + 1], width: math.nan() },
		layout.PaintCommand{ ...commands[start + 1], transform: [f64(1), 0, 0, 1, 1, 0]! }] {
		mut changed := commands.clone()
		changed[start + 1] = replacement
		assert inset_group_end(changed, layers, start) == start
	}
	mut other := layers.clone()
	other[start + 1] = 1
	assert inset_group_end(commands, other, start) == start
	assert inset_group_end(commands, []int{}, start) == start
	assert inset_group_end(commands, layers, -1) == -1
	assert inset_group_end(commands, layers, commands.len) == commands.len
	assert inset_group_end(commands[..start + 2], layers[..start + 2], start) == start
}
