module layout

import html

fn local_background_commands(chromium bool) []PaintCommand {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}.circle{position:absolute;left:1212px;top:132px;width:22px;height:22px;border-radius:50%;background:#fafafa}#local{transform:translateX(0)}#global{top:180px}</style><div class="circle" id="local"></div><div class="circle" id="global"></div>')
	defer { document.finalize() }
	if chromium { document.set_font_rendering_policy(.chromium) }
	_ = layout_document_typed_in_viewport(document, 1280, 800)
	return display_list_commands(document.record_display_list() or { panic('missing paint') }).filter((it.kind == 'fill_rect' && it.radius > 0) || it.kind == 'fill_rounded_rect')
}

fn test_identity_css_transform_retains_local_rounded_background_geometry() {
	commands := local_background_commands(true)
	assert commands.len == 2
	assert commands[0].x == 0 && commands[0].y == 0
	assert commands[0].width == 22 && commands[0].height == 22
	assert commands[0].transform == [f64(1), 0, 0, 1, 1212, 132]!
	assert commands[0].local_border_data != unsafe { nil }
	assert commands[1].x == 1212 && commands[1].y == 180
	assert commands[1].local_border_data == unsafe { nil }
}

fn test_libweb_rounded_background_coordinates_are_preserved() {
	commands := local_background_commands(false)
	assert commands.len == 2
	assert commands[0].x == 1212 && commands[0].y == 132
	assert commands[0].local_border_data == unsafe { nil }
}
