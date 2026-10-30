module layout

import html

fn local_border_shadow_commands(transform string, chromium bool) []PaintCommand {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}div{position:absolute;left:80.25px;top:130.03125px;width:600px;height:280px;border:1px solid #a6c6f415;border-radius:50%;transform:${transform};box-shadow:0 -15px 60px #79a8f309,0 -1px 0 #a6c6f40d}</style><div></div>')
	defer { document.finalize() }
	if chromium { document.set_font_rendering_policy(.chromium) }
	_ = layout_document_typed_in_viewport(document, 800, 600)
	return display_list_commands(document.record_display_list() or { panic('missing paint') })
		.filter(it.kind in ['paint_uniform_border', 'paint_outer_box_shadow'])
}

fn test_rotated_border_and_shadow_keep_one_local_paint_offset() {
	commands := local_border_shadow_commands('rotate(-24deg)', true)
	assert commands.len == 3
	for command in commands {
		data := command.local_border_data
		assert data != unsafe { nil }
		assert data.origin_x == 80.25 && data.origin_y == 130.03125
		if command.kind == 'paint_uniform_border' {
			assert command.x == 0.5 && command.y == 0.5
			assert command.width == 601 && command.height == 281
		} else {
			assert command.box_shadow_data.content_rect == LayoutRect{0, 0, 602, 282}
		}
	}
}

fn test_local_decorations_keep_translation_and_libweb_fallbacks() {
	for commands in [local_border_shadow_commands('translateX(1px)', true),
		local_border_shadow_commands('rotate(-24deg)', false)] {
		assert commands.len > 0
		for command in commands {
			assert command.local_border_data == unsafe { nil }
			assert command.x >= 80
		}
	}
}
