module layout

import css
import html
import painting

fn hidden_paint_server_style_change(property string, stop_color string) {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}svg{display:block}</style><svg width="100" height="100"><defs id="resources" style="display:none;${property}:red"><linearGradient id="paint" gradientUnits="userSpaceOnUse"><stop offset="0" style="stop-color:${stop_color}"/><stop offset="1" style="stop-color:${stop_color}"/></linearGradient></defs><rect width="100" height="100" fill="url(#paint)"/></svg>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 100, 100)
	first := display_list_commands(document.record_display_list() or { panic('first recording') }).filter(it.kind == 'draw_svg_path')[0]
	original := first.fill_linear_gradient() or { panic('original gradient') }
	assert original.gradient.color_stops[0].color == painting.Color{255, 0, 0, 255}
	resources := document.get_element_by_id('resources') or { panic('resources') }
	mut declaration := css.element_style(resources)
	declaration.set_property(property, 'green', '') or { panic(err) }
	document.update_layout(.dump_display_list)
	second := display_list_commands(document.record_display_list() or { panic('updated recording') }).filter(it.kind == 'draw_svg_path')[0]
	updated := second.fill_linear_gradient() or { panic('updated gradient') }
	assert updated.gradient.color_stops[0].color == painting.Color{0, 128, 0, 255}
	assert updated.gradient.color_stops[1].color == painting.Color{0, 128, 0, 255}
	// Paint snapshots already retained by a frame keep their original colors.
	assert original.gradient.color_stops[0].color == painting.Color{255, 0, 0, 255}
}

fn test_hidden_paint_server_repaints_after_inherited_custom_property_changes() {
	hidden_paint_server_style_change('--paint-color', 'var(--paint-color)')
}

fn test_hidden_paint_server_repaints_after_inherited_currentcolor_changes() {
	hidden_paint_server_style_change('color', 'currentColor')
}
