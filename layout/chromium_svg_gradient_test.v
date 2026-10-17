module layout

import html

fn chromium_svg_gradient_fill(policy_chromium bool) PaintCommand {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}</style>
		<svg width="80" height="60"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="0.6">
		<stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#36c"/></linearGradient></defs>
		<rect x="10" y="10" width="60" height="40" fill="url(#g)"/></svg>')
	if policy_chromium {
		document.set_font_rendering_policy(.chromium)
	}
	mut root := layout_document_typed_in_viewport(document, 200, 100)
	return root.paint_commands().filter(it.kind == 'draw_svg_path')[0]
}

// SVG maps objectBoundingBox gradient coordinates through the bounding-box
// transform, skewing linear isolines on a non-square box as Chromium does.
fn test_chromium_object_bounding_box_gradients_use_unit_space() {
	blink := chromium_svg_gradient_fill(true).fill_linear_gradient() or { panic('missing gradient') }
	assert blink.start_point.x == 0 && blink.start_point.y == 0
	assert blink.end_point.x == 1 && blink.end_point.y == 0.6
	transform := blink.gradient.gradient_transform or { panic('missing gradient transform') }
	assert transform.a == 60 && transform.d == 40 && transform.e == 10 && transform.f == 10
	assert transform.b == 0 && transform.c == 0
	// LibWeb maps only the endpoints into user space.
	libweb := chromium_svg_gradient_fill(false).fill_linear_gradient() or { panic('missing gradient') }
	assert libweb.start_point.x == 10 && libweb.end_point.x == 70 && libweb.end_point.y == 34
	if libweb_transform := libweb.gradient.gradient_transform {
		assert libweb_transform.a == 1 && libweb_transform.d == 1
	}
}
