module css

import dom

fn assert_font_refresh_parent_values_match(subject dom.AbstractElement) {
	parent := parent_computed_properties(subject)
	for id in computed_interpolation_longhand_property_ids() {
		actual := font_refresh_parent_value(id, subject, parent)
		expected := StyleComputer.get_non_animated_inherit_value(id, subject)
		assert voidptr(actual) == voidptr(expected), string_from_property_id(id)
	}
}

fn test_font_refresh_parent_borrow_reads_live_stores_and_initial_values() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut parent := document.create_element('div')!
	child := document.create_element('span')!
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node())!
	subject := dom.AbstractElement.new(child, none)
	assert_font_refresh_parent_values_match(subject)
	computer := StyleComputer.new(document)
	mut parent_subject := dom.AbstractElement.new(parent, none)
	mut source := computer.recompute_style(mut parent_subject)
	borrowed := parent_computed_properties(subject)
	for text in ['red', 'blue'] {
		value := parse_css_value(ParsingParams{}, text, .color) or { panic('color') }
		source.set_property(.color, value, .no, .no)
		assert voidptr(font_refresh_parent_value(.color, subject, borrowed)) == voidptr(value)
		assert_font_refresh_parent_values_match(subject)
	}
	animated := parse_css_value(ParsingParams{}, 'green', .color) or { panic('animation') }
	source.set_animated_property(.color, animated, .yes, .no)
	assert voidptr(font_refresh_parent_value(.color, subject, borrowed)) != voidptr(animated)
	assert_font_refresh_parent_values_match(subject)
}

fn test_font_refresh_parent_is_resolved_again_after_reparent_override_and_style_replacement() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut first := document.create_element('div')!
	first.set_attribute_value('style', 'color:red')
	mut second := document.create_element('div')!
	second.set_attribute_value('style', 'color:blue')
	child := document.create_element('span')!
	computer := StyleComputer.new(document)
	mut first_subject := dom.AbstractElement.new(first, none)
	mut second_subject := dom.AbstractElement.new(second, none)
	computer.recompute_style(mut first_subject)
	computer.recompute_style(mut second_subject)
	mut first_node := first.as_node()
	first_node.append_child(child.as_node())!
	mut subject := dom.AbstractElement.new(child, none)
	assert_font_refresh_parent_values_match(subject)
	mut second_node := second.as_node()
	second_node.append_child(child.as_node())!
	assert_font_refresh_parent_values_match(subject)
	assert font_refresh_parent_value(.color, subject, parent_computed_properties(subject)).css_text == 'rgb(0, 0, 255)'
	subject.set_inheritance_override(first)
	assert_font_refresh_parent_values_match(subject)
	assert font_refresh_parent_value(.color, subject, parent_computed_properties(subject)).css_text == 'rgb(255, 0, 0)'
	first.set_attribute_value('style', 'color:green')
	computer.recompute_style(mut first_subject)
	assert_font_refresh_parent_values_match(subject)
	assert font_refresh_parent_value(.color, subject, parent_computed_properties(subject)).css_text == 'rgb(0, 128, 0)'
	for pseudo in [dom.PseudoElement.before, .after, .selection, .marker] {
		assert_font_refresh_parent_values_match(dom.AbstractElement.new(first, pseudo))
	}
	mut child_node := child.as_node()
	child_node.remove(false)
	assert_font_refresh_parent_values_match(dom.AbstractElement.new(child, none))
}

fn test_font_refresh_parent_guard_rejects_changed_explicit_noninherited_inputs() {
	for property in ['background-color', 'opacity'] {
		mut document, root, subject, _ := font_input_fixture()
		defer { document.finalize() }
		mut target := unsafe { &dom.Element(subject) }
		target.set_attribute_value('style', '${property}:inherit;width:120px')
		document.update_style()
		computer := css_style_computer_for(document)
		abstract := dom.AbstractElement.new(subject, none)
		assert computer.can_refresh_font_inputs(abstract), property
		id := property_id_from_string(property) or { panic('property') }
		mut parent := unsafe { &ComputedProperties(font_input_style(root, none)) }
		previous := parent.property(id, .no) or { panic('previous') }
		replacement := parse_css_value(ParsingParams{}, if property == 'opacity' { '0.5' } else { 'red' }, id) or { panic('replacement') }
		parent.set_property(id, replacement, .no, .no)
		assert !computer.can_refresh_font_inputs(abstract), property
		parent.set_property(id, previous, .no, .no)
		assert computer.can_refresh_font_inputs(abstract), property
	}
}

fn test_font_refresh_parent_guard_observes_payload_mutation_without_mutating_child() {
	mut document, root, subject, _ := font_input_fixture()
	defer { document.finalize() }
	mut target := unsafe { &dom.Element(subject) }
	target.set_attribute_value('style', 'color:inherit;width:120px')
	document.update_style()
	computer := css_style_computer_for(document)
	child := font_input_style(subject, none)
	bridge := subject.el_computed_properties() or { panic('bridge') }
	abstract := dom.AbstractElement.new(subject, none)
	assert computer.can_refresh_font_inputs(abstract)
	mut source := unsafe { &ComputedProperties(font_input_style(root, none)) }
	// Distinct equal values ensure an in-place parent edit does not also edit
	// the child's graph through an alias.
	previous := child.property(.color, .no) or { panic('child color') }
	typed := typed_style_value_logic_from_dom(previous) or { panic('typed child color') }
	value := dom_style_value_from_value_logic(typed)
	source.set_property(.color, value, .no, .no)
	assert computer.can_refresh_font_inputs(abstract)
	mut box := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	box.value = StyleValue(ColorStyleValue.create(Color.rgba(255, 0, 0, 255)))
	assert !computer.can_refresh_font_inputs(abstract)
	assert voidptr(font_input_style(subject, none)) == voidptr(child)
	assert voidptr(subject.el_computed_properties() or { panic('bridge') }) == voidptr(bridge)
}
