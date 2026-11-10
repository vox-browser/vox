module css

import dom

fn resolved_transform_text(declaration string) string {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	mut root := document.create_element('html') or { panic(err) }
	root.set_attribute_value('style', declaration)
	mut node := document.as_node()
	node.append_child(root.as_node()) or { panic(err) }
	_ = css_style_computer_for(document)
	document.update_style()
	style := up_to_date_computed_properties_for_element(root)
	layout_node := &dom.LayoutNode{}
	resolved := cssom_resolved_transform(style, layout_node) or { panic('missing resolved transform') }
	return resolved.css_text
}

fn test_resolved_transform_keeps_half_turns_about_tilted_axes_three_dimensional() {
	// m33 is -1 here, so the matrix is not 2D even though every other
	// three-dimensional component is zero.
	resolved := resolved_transform_text('transform: rotate3d(1, 1, 0, 180deg)')
	assert resolved.starts_with('matrix3d('), resolved
	assert resolved_transform_text('transform: scale3d(1, 1, -1)').starts_with('matrix3d(')
	assert resolved_transform_text('transform: rotate(90deg) translate(10px, 0px)') == 'matrix(0, 1, -1, 0, 0, 10)'
}
