module css

import dom

fn projection_storage_style() (&dom.Document, &ComputedProperties) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_navigable(&dom.Navigable{active_document_: document})
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	document.set_font_rendering_policy(.chromium)
	mut root := document.create_element('html') or { panic(err) }
	root.set_attribute_value('style', 'font:17px Arial;width:7px')
	mut node := document.as_node()
	node.append_child(root.as_node()) or { panic(err) }
	_ = css_style_computer_for(document)
	document.update_style()
	return document, up_to_date_computed_properties_for_element(root)
}

fn test_density_projection_does_not_materialize_a_source_layout_cache() {
	mut document, mut source := projection_storage_style()
	defer { document.finalize() }
	assert voidptr(source.computed_layout_cache_) == unsafe { nil }
	document.set_layout_coordinate_scale(2)
	first := computed_style_in_layout_coordinates(source, document)
	assert voidptr(source.computed_layout_cache_) == unsafe { nil }
	assert voidptr(first.device_layout_projection_) == unsafe { nil }
	assert voidptr(computed_style_in_layout_coordinates(source, document)) == voidptr(first)
	assert first.length_percentage_to_px(.width, 1600) or { panic('missing projected width') } == 14
	assert source.length_percentage_to_px(.width, 800) or { panic('missing source width') } == 7
	source.set_property_without_modifying_flags(.width,
		dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(9)))))
	second := computed_style_in_layout_coordinates(source, document)
	assert voidptr(first) != voidptr(second)
	assert voidptr(source.computed_layout_cache_) == unsafe { nil }
	assert voidptr(second.device_layout_projection_) == unsafe { nil }
	assert first.length_percentage_to_px(.width, 1600) or { panic('missing old width') } == 14
	assert second.length_percentage_to_px(.width, 1600) or { panic('missing new width') } == 18
	document.set_layout_coordinate_scale(3)
	third := computed_style_in_layout_coordinates(source, document)
	assert voidptr(second) != voidptr(third)
	assert voidptr(source.computed_layout_cache_) == unsafe { nil }
	assert third.length_percentage_to_px(.width, 2400) or { panic('missing rescaled width') } == 27
}

fn test_density_projection_preserves_an_existing_source_layout_snapshot() {
	mut document, source := projection_storage_style()
	defer { document.finalize() }
	_ = resolve_computed_values_for_document(source, document)
	snapshot := source.computed_layout_cache()
	assert voidptr(snapshot) != unsafe { nil }
	document.set_layout_coordinate_scale(2)
	projected := computed_style_in_layout_coordinates(source, document)
	assert voidptr(source.computed_layout_cache()) == voidptr(snapshot)
	assert source.layout_coordinate_scale() == 1
	assert projected.layout_coordinate_scale() == 2
	assert voidptr(computed_style_in_layout_coordinates(source, document)) == voidptr(projected)
}
