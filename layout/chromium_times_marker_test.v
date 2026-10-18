module layout

import html

fn test_chromium_times_disc_uses_the_adjusted_inline_ascent() {
	$if macos {
		mut document := html.parse_document('<!doctype html><style>html,body{margin:0}body{font:16px/1.3 Times}ul{margin:0;padding-left:40px}::marker{color:red}</style><ul><li>item</li></ul>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		root := layout_document_typed_in_viewport(document, 320, 100)
		markers := root.paint_commands().filter(it.kind == 'fill_ellipse')
		assert markers.len == 1
		assert markers[0].x == 24
		assert markers[0].width == 5
		assert markers[0].height == 5
	}
}
