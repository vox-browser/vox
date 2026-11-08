module layout

import html

fn test_svg_bounding_box_hit_testing_includes_the_nonempty_box_edges() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}</style><svg width="200" height="100"><circle id="target" cx="50" cy="50" r="20" visibility="hidden" pointer-events="bounding-box"/></svg>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 200, 100)
	target := document.get_element_by_id('target') or { panic('target') }
	for point in [[f64(30), 30], [f64(70), 70], [f64(30), 70], [f64(70), 30]] {
		assert svg_pointer_hits(mut document, target, point[0], point[1]), '${point}'
	}
	assert !svg_pointer_hits(mut document, target, 70.1, 70)
	assert !svg_pointer_hits(mut document, target, 29.9, 30)
}

fn test_svg_text_bounding_box_includes_descendant_lines_and_the_gaps_between_them() {
	for scale in [f64(1), 2] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}</style><svg width="300" height="200"><text id="target" x="10" y="20" font-family="monospace" font-size="10" transform="translate(20 30)" pointer-events="bounding-box" opacity="0">M<tspan id="span" x="100" dy="3em">M</tspan></text></svg>')
		document.set_layout_coordinate_scale(scale)
		document.set_display_device_pixel_ratio(scale)
		_ = layout_document_typed_in_viewport(document, 400, 300)
		mut target := document.get_element_by_id('target') or { panic('target') }
		span := document.get_element_by_id('span') or { panic('span') }
		assert svg_pointer_hits(mut document, span, 123, 76), 'scale=${scale}'
		assert svg_pointer_hits(mut document, target, 70, 65), 'scale=${scale}'
		assert !svg_pointer_hits(mut document, target, 29, 65)
		target.set_attribute_value('pointer-events', 'fill')
		assert !svg_pointer_hits(mut document, target, 70, 65)
		document.finalize()
	}
}

fn test_svg_hidden_image_pointer_modes_use_the_transformed_image_viewport() {
	for scale in [f64(1), 2] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}</style><svg width="200" height="200"><image id="target" width="50" height="30" transform="translate(20 100)" visibility="hidden" opacity="0" pointer-events="bounding-box" href="data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 50 30%22/%3E"/></svg>')
		document.set_layout_coordinate_scale(scale)
		document.set_display_device_pixel_ratio(scale)
		_ = layout_document_typed_in_viewport(document, 300, 300)
		mut target := document.get_element_by_id('target') or { panic('target') }
		for mode in ['bounding-box', 'all', 'fill', 'stroke', 'painted'] {
			target.set_attribute_value('pointer-events', mode)
			assert svg_pointer_hits(mut document, target, 25, 105), '${mode} scale=${scale}'
			assert svg_pointer_hits(mut document, target, 65, 125), '${mode} scale=${scale}'
			assert !svg_pointer_hits(mut document, target, 15, 105), mode
		}
		for mode in ['none', 'auto', 'visiblePainted', 'visibleFill', 'visibleStroke', 'visible'] {
			target.set_attribute_value('pointer-events', mode)
			assert !svg_pointer_hits(mut document, target, 25, 105), mode
		}
		document.finalize()
	}
}
