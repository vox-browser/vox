module layout

import dom
import html

fn test_chromium_svg_ellipse_preserves_fractional_user_units_and_css_overrides() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#oval{rx:calc(1% + .2px);ry:auto;cx:10.1px;cy:20.2px}</style><svg width="140" height="100"><ellipse rx="1.6" ry=".8"/><ellipse id="oval" rx="10" ry="20"/><circle r="1.6"/></svg>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 200, 100)
	commands := display_list_commands(document.record_display_list() or { panic('missing display list') }).filter(it.kind == 'draw_svg_path')
	assert commands.len == 3
	assert commands[0].svg().path_data[1..5] == [f32(-1.6), -.8, 1.6, .8]
	rx := f32(1.6)
	cx := f32(10.1)
	cy := f32(20.2)
	assert commands[1].svg().path_data[1..5] == [cx - rx, cy - rx, cx + rx, cy + rx]
	assert commands[2].svg().path_data[1..5] == [f32(-1.6), -1.6, 1.6, 1.6]
}
