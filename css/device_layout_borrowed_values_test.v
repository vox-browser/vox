module css

import dom

fn borrowed_projection_test_style() (&dom.Document, &ComputedProperties) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.set_navigable(&dom.Navigable{ active_document_: document })
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	document.set_font_rendering_policy(.chromium)
	mut root := document.create_element('html') or { panic(err) }
	root.set_attribute_value('style', 'font:16px Arial;width:0px;padding:0px;color:red;opacity:.5;border:thin solid;transform:translate(3px,4px)')
	mut node := document.as_node()
	node.append_child(root.as_node()) or { panic(err) }
	_ = css_style_computer_for(document)
	document.update_style()
	return document, up_to_date_computed_properties_for_element(root)
}

fn test_projection_keeps_borrowed_values_and_still_scales_replaced_and_nested_lengths() {
	mut document, mut source := borrowed_projection_test_style()
	defer { document.finalize() }
	document.set_layout_coordinate_scale(2)
	first := computed_style_in_layout_coordinates(source, document)
	for property in [PropertyID.width, .padding_left, .color, .opacity] {
		assert voidptr(first.property(property, .yes)?) == voidptr(source.property(property, .yes)?)
	}
	assert first.length_percentage_to_px(.border_top_width, 1600)? == 2
	assert first.property(.transform, .yes)?.css_text == 'translate(6px, 8px)'
	source.set_property_without_modifying_flags(.width,
		dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(8)))))
	second := computed_style_in_layout_coordinates(source, document)
	assert voidptr(second) != voidptr(first)
	assert first.length_percentage_to_px(.width, 1600)? == 0
	assert second.length_percentage_to_px(.width, 1600)? == 16
	assert source.length_percentage_to_px(.width, 800)? == 8
}

fn test_projection_preserves_untyped_dom_values_and_dimensionless_animation_values() {
	mut document, mut source := borrowed_projection_test_style()
	defer { document.finalize() }
	source.set_property_without_modifying_flags(.width, &dom.StyleValue{ css_text: 'calc(50% - 3px)' })
	source.set_property_without_modifying_flags(.border_top_width, &dom.StyleValue{ css_text: '5px' })
	source.set_property_without_modifying_flags(.outline_width,
		dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.thick))))
	source.set_property_without_modifying_flags(.padding_left, &dom.StyleValue{ css_text: '0px' })
	animated := dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(0.25)))
	source.set_animated_property(.opacity, animated, .no, .no)
	for scale in [0.5, 2.0, 3.0] {
		document.set_layout_coordinate_scale(scale)
		projected := computed_style_in_layout_coordinates(source, document)
		assert projected.length_percentage_to_px(.width, 800 * scale)? == 397 * scale
		assert projected.length_percentage_to_px(.border_top_width, 800 * scale)? == 5 * scale
		assert projected.length_percentage_to_px(.outline_width, 800 * scale)? == 5 * scale
		assert voidptr(projected.property(.padding_left, .yes)?) == voidptr(source.property(.padding_left, .yes)?)
		assert voidptr(projected.property(.opacity, .yes)?) == voidptr(animated)
	}
}
