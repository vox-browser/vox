module layout

import html

fn test_svg_author_path_length_matches_paint_and_dom_stroke_hit_geometry() {
	for author_length in ['100', '0', '-5', 'invalid', ''] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}</style>
			<svg width="240" height="100"><path id="path" d="M0 20H200" pathLength="${author_length}"
				fill="none" stroke="black" stroke-width="4" stroke-dasharray="25 100" stroke-dashoffset="5"/></svg>')
		defer { document.finalize() }
		root := layout_document_typed_in_viewport(document, 300, 150)
		paths := root.paint_commands().filter(it.kind == 'draw_svg_path')
		assert paths.len == 1
		element := document.get_element_by_id('path') or { panic('missing path') }
		geometry := svg_dom_geometry(element)
		expected := if author_length == '0' { []f64{} } else if author_length == '100' { [f64(50), 200] } else { [f64(25), 100] }
		expected_offset := if author_length == '0' { 0.0 } else if author_length == '100' { 10.0 } else { 5.0 }
		assert paths[0].svg().stroke_dasharray == expected
		assert paths[0].svg().stroke_dashoffset == expected_offset
		assert geometry.dashes == expected.map(f32(it))
		assert geometry.dash_offset == expected_offset
		assert geometry.contains_point(30, 20, true) == (author_length in ['100', '0'])
		assert geometry.contains_point(80, 20, true) == (author_length == '0')
		assert geometry.path.length() == 200
	}
}

fn test_svg_path_length_mutation_invalidates_layout_and_refreshes_retained_strokes() {
	mut document := html.parse_document('<!doctype html><svg width="240" height="100"><path id="path"
		d="M10 20H110" fill="none" stroke="black" stroke-dasharray="2 3"/></svg>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 300, 150)
	mut element := document.get_element_by_id('path') or { panic('missing path') }
	mut layout_node := element.as_node().layout_node() or { panic('missing layout node') }
	layout_node.reset_needs_layout_update()
	element.set_attribute_value('pathLength', '10')
	assert layout_node.needs_layout_update()
	document.update_layout(.debugging)
	paths := display_list_commands(document.record_display_list() or { panic('missing paint') })
		.filter(it.kind == 'draw_svg_path')
	assert paths.len == 1
	assert paths[0].svg().stroke_dasharray == [f64(20), 30]
	assert svg_dom_geometry(element).dashes == [f32(20), 30]
}
