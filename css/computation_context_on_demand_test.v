module css

import dom

fn on_demand_context_tree(parent_declarations string, child_declarations string) (&StyleComputer, &ComputedProperties, &dom.Element, &dom.Element) {
	document := dom.Document.create(dom.url_about_blank())
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_viewport_rect(dom.Rect{0, 0, 500, 300})
	mut parent := document.create_element('html') or { panic(err) }
	parent.set_attribute_value('style', parent_declarations)
	mut child := document.create_element('div') or { panic(err) }
	child.set_attribute_value('style', child_declarations)
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(parent.as_node()) or { panic(err) }
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic(err) }
	computer := StyleComputer.new(document)
	computed := computer.compute_style(dom.AbstractElement.new(parent, none))
	parent.set_computed_properties(none, computed_properties_to_dom(computed))
	return computer, computed, parent, child
}

fn test_context_free_inheritance_retains_resolved_identity_and_flags() {
	computer, parent_style, _, child := on_demand_context_tree('font-family:sans-serif; font-size:20px; line-height:30px; color:rgb(17 34 51); letter-spacing:2px; visibility:hidden; writing-mode:vertical-rl; direction:rtl', '')
	computed := computer.compute_style(dom.AbstractElement.new(child, none))
	for id in [PropertyID.font_family, .font_size, .line_height, .color, .letter_spacing,
		.visibility, .writing_mode, .direction] {
		assert !property_requires_computation_with_inherited_value(id)
		assert computed.is_property_inherited(id)
		assert !computed.is_property_important(id)
		assert voidptr(computed.property(id, .no)?) == voidptr(parent_style.property(id, .no)?)
	}
	assert computed.font_size().to_double() == 20
	assert computed.line_height().to_double() == 30
	assert computed.color_or_fallback(.color, ColorResolutionContext{}, ComputedColor.rgba(0, 0, 0, 0)) == ComputedColor.rgba(17, 34, 51, 255)
	assert computed.writing_mode() == .vertical_rl
	assert computed.direction() == .rtl
	assert computer.computation_context_cache_is_empty()
	gc_collect()
	assert computed.property(.letter_spacing, .no)?.css_text == '2px'
}

fn test_inherited_viewport_font_dependencies_reach_relative_lengths_without_leaking_to_fixed_styles() {
	computer, parent_style, parent, child := on_demand_context_tree('font-size:10vw; line-height:2em', 'width:2em')
	assert parent_style.font_size().to_double() == 50
	assert parent_style.line_height().to_double() == 100
	assert parent_style.font_metrics_depend_on_viewport_metrics()
	computed := computer.compute_style(dom.AbstractElement.new(child, none))
	assert computed.is_property_inherited(.font_size)
	assert computed.is_property_inherited(.line_height)
	assert computed.font_metrics_depend_on_viewport_metrics()
	assert computed.depends_on_viewport_metrics()
	assert computed.length_percentage_to_px(.width, 0)? == 100
	assert computer.computation_context_cache_is_empty()
	mut sibling := parent.document().create_element('div') or { panic(err) }
	sibling.set_attribute_value('style', 'font-size:12px; line-height:1; width:2em')
	mut parent_node := parent.as_node()
	parent_node.append_child(sibling.as_node()) or { panic(err) }
	fixed := computer.compute_style(dom.AbstractElement.new(sibling, none))
	assert !fixed.is_property_inherited(.font_size)
	assert !fixed.is_property_inherited(.line_height)
	assert !fixed.font_metrics_depend_on_viewport_metrics()
	assert !fixed.depends_on_viewport_metrics()
	assert fixed.length_percentage_to_px(.width, 0)? == 24
	assert computer.computation_context_cache_is_empty()
	gc_collect()
	assert computed.length_percentage_to_px(.width, 0)? == 100
}

fn test_required_font_and_line_height_contexts_keep_parent_and_current_metrics() {
	computer, _, _, child := on_demand_context_tree('font-size:20px; line-height:30px', 'font-size:150%; line-height:2em; width:2lh; height:2rem')
	computed := computer.compute_style(dom.AbstractElement.new(child, none))
	assert computed.font_size().to_double() == 30
	assert computed.line_height().to_double() == 60
	assert computed.length_percentage_to_px(.width, 0)? == 120
	assert computed.length_percentage_to_px(.height, 0)? == 40
	assert !computed.is_property_inherited(.font_size)
	assert !computed.is_property_inherited(.line_height)
	assert !computed.font_metrics_depend_on_viewport_metrics()
	assert !computed.depends_on_viewport_metrics()
	assert computer.computation_context_cache_is_empty()
}

fn test_inherited_background_lists_still_recompute_against_the_child_layer_count() {
	computer, parent_style, _, child := on_demand_context_tree('font-size:20px; background-image:none,none; background-position-x:2em; background-repeat:no-repeat', 'font-size:10px; background-image:none,none,none; background-position-x:inherit; background-repeat:inherit')
	assert parent_style.property(.background_position_x, .no)?.css_text == '40px, 40px'
	computed := computer.compute_style(dom.AbstractElement.new(child, none))
	assert property_requires_computation_with_inherited_value(.background_position_x)
	assert property_requires_computation_with_inherited_value(.background_repeat)
	assert computed.is_property_inherited(.background_position_x)
	assert computed.is_property_inherited(.background_repeat)
	assert computed.property(.background_position_x, .no)?.css_text == '40px, 40px, 40px'
	assert computed.property(.background_repeat, .no)?.css_text == 'no-repeat, no-repeat, no-repeat'
	assert computed.font_size().to_double() == 10
	assert computer.computation_context_cache_is_empty()
	gc_collect()
	assert parent_style.property(.background_repeat, .no)?.css_text == 'no-repeat, no-repeat'
}
