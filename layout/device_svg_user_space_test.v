module layout

import html

fn test_device_layout_svg_strokes_stay_in_the_viewbox_user_space() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}</style>
		<svg id="icon" width="24" height="24" viewBox="0 0 24 24">
		<path d="M4 8L12 16L20 8" fill="none" stroke="black" stroke-width="1.5"/></svg>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	document.set_display_device_pixel_ratio(2)
	document.set_layout_coordinate_scale(2)
	root := layout_document_typed_in_viewport(document, 300, 150)
	paths := root.paint_commands().filter(it.kind == 'draw_svg_path' && it.stroke_width > 0)
	assert paths.len == 1
	assert paths[0].stroke_width == 1.5
	icon := document.get_element_by_id('icon') or { panic('icon') }
	assert icon.get_bounding_client_rect().width == 24
}

fn test_device_layout_svg_em_strokes_and_dashes_use_the_unscaled_svg_font() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}svg{font:20px Arial}</style>
		<svg width="48" height="48" viewBox="0 0 24 24"><path d="M4 8H20"
		fill="none" stroke="black" stroke-width=".1em" stroke-dasharray=".2em 1px"
		stroke-dashoffset=".05em" vector-effect="non-scaling-stroke"/></svg>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	document.set_display_device_pixel_ratio(2)
	document.set_layout_coordinate_scale(2)
	root := layout_document_typed_in_viewport(document, 300, 150)
	paths := root.paint_commands().filter(it.kind == 'draw_svg_path' && it.stroke_width > 0)
	assert paths.len == 1
	assert paths[0].stroke_width == 2
	assert paths[0].svg().stroke_dasharray == [f64(4), 1]
	assert paths[0].svg().stroke_dashoffset == 1
	assert paths[0].svg().non_scaling_stroke
}

fn test_device_svg_without_viewbox_preserves_percentage_and_nested_user_spaces() {
	for scale in [f64(1), 2] {
		mut document := html.parse_document('<!doctype html><style>html,body{margin:0}svg{display:block}</style><svg id="root" width="200" height="100"><rect id="percent" width="50%" height="50%"/><svg x="100" width="100" height="100"><rect id="nested" width="50%" height="50%"/></svg></svg><svg width="200" height="100" viewBox="0 0 100 50"><rect id="authored" x="20" y="10" width="40" height="20"/></svg>')
		document.set_layout_coordinate_scale(scale)
		document.set_display_device_pixel_ratio(scale)
		root := layout_document_typed_in_viewport(document, 400, 300)
		percent := document.get_element_by_id('percent') or { panic('percent') }
		nested := document.get_element_by_id('nested') or { panic('nested') }
		authored := document.get_element_by_id('authored') or { panic('authored') }
		assert percent.get_bounding_client_rect().width == 100
		assert percent.get_bounding_client_rect().height == 50
		assert nested.get_bounding_client_rect().x == 100
		assert nested.get_bounding_client_rect().width == 50
		authored_box := root.find_box(i64(authored.as_node().unique_id())) or { panic('authored box') }
		assert authored_box.svg_path().path_transform[0] == 2 * scale
		assert authored.get_bounding_client_rect().x == 40
		assert authored.get_bounding_client_rect().width == 80
		document.finalize()
	}
}
