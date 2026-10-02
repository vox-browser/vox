module layout

import css
import dom
import html

fn viewport_transform_owner() !(&dom.Document, &html.WindowModel) {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}</style><body></body>')
	window := html.WindowModel.create_top_level(document, none, 'viewport-transform')!
	_ = layout_document_typed_in_viewport(document, 200, 100)
	return document, window
}

fn test_visual_viewport_transform_keeps_unrounded_scaled_offset_and_source_float_inverse() {
	mut document, mut window := viewport_transform_owner()!
	mut viewport := window.visual_viewport() or { panic('VisualViewport') }
	viewport.zoom(css.CSSPixelPoint.from_values(1.25, 2.25), 0.3)
	facade := document.visual_viewport()
	assert facade.scale() == 1.3 && facade.offset_left() == 0.28125 && facade.offset_top() == 0.515625
	transform := viewport.transform()
	assert transform.scale_x == f32(1.3) && transform.scale_y == f32(1.3)
	assert transform.translate_x == f32(-0.365625) && transform.translate_y == f32(-0.6703125)
	assert transform.shear_x == 0 && transform.shear_y == 0
	inverse := transform.inverse() or { panic('inverse') }
	// The source float determinant/inverse differs from double 1/1.3.
	assert inverse.scale_x == f32(0.769230842590332)
	assert viewport.map_to_layout_viewport(css.CSSPixelPoint.from_values(100.75, 20.75)).to_double_pair() == [
		f64(77),
		16,
	]!
}

fn test_visual_viewport_integer_mapping_truncates_input_and_rounds_float_ties_to_even() {
	_, mut window := viewport_transform_owner()!
	mut viewport := window.visual_viewport() or { panic('VisualViewport') }
	viewport.zoom(css.CSSPixelPoint.from_values(0, 0), 1)
	assert viewport.map_to_layout_viewport(css.CSSPixelPoint.from_values(1.75, 3.75)).to_double_pair() == [
		f64(0),
		2,
	]!
	assert viewport.map_to_layout_viewport(css.CSSPixelPoint.from_values(-1.75, -3.75)).to_double_pair() == [
		f64(0),
		-2,
	]!
	viewport.zoom(css.CSSPixelPoint.from_values(1.25, 2.25), 0.5)
	assert viewport.offset_left() == 0.203125 && viewport.offset_top() == 0.375
	assert viewport.map_to_layout_viewport(css.CSSPixelPoint.from_values(17.75, -5.75)).to_double_pair() == [
		f64(6),
		-1,
	]!
}

fn test_visual_viewport_identity_mapping_retains_source_int_to_float_precision_boundary() {
	_, mut window := viewport_transform_owner()!
	viewport := window.visual_viewport() or { panic('VisualViewport') }
	point := css.CSSPixelPoint.new(css.CSSPixels.new(16777217), css.CSSPixels.new(-16777217))
	assert viewport.map_to_layout_viewport(point).to_double_pair() == [f64(16777216), -16777216]!
}
