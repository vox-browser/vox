module layout

import html

fn test_chromium_outside_symbols_paint_geometry_and_keep_textual_fallbacks() {
	for rules in ['', 'list-style-position:inside'] {
		mut document :=
			html.parse_document('<!doctype html><style>li{${rules}}</style><ul><li>item</li></ul>')
		document.set_font_rendering_policy(.chromium)
		root := layout_document_typed_in_viewport(document, 320, 100)
		commands := root.paint_commands()
		if rules == '' {
			markers := commands.filter(it.kind == 'fill_ellipse')
			assert markers.len == 1
			assert markers[0].width > 0 && markers[0].width == markers[0].height
			assert !commands.any(it.kind == 'draw_text' && it.text.contains('•'))
		} else {
			assert !commands.any(it.kind == 'fill_ellipse')
		}
	}
}

fn test_chromium_authored_marker_retains_fractional_inline_position() {
	mut document :=
		html.parse_document('<!doctype html><style>body{font:13.333333px Arial}li::marker{content:"custom "}</style><ul><li>item</li></ul>')
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document, 320, 100)
	commands := root.paint_commands()
	assert !commands.any(it.kind == 'fill_ellipse')
	markers := commands.filter(it.kind == 'draw_text' && it.text == 'custom ')
	assert markers.len == 1
	text := commands.filter(it.kind == 'draw_text' && it.text == 'item')
	assert text.len == 1
	assert markers[0].x + markers[0].width == text[0].x
}
