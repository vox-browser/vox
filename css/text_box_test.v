module css

import dom

fn test_text_box_longhands_register_defaults_inheritance_and_layout_invalidation() {
	assert number_of_longhand_properties == int(last_longhand_property_id()) - int(first_longhand_property_id()) + 1
	for index in 0 .. number_of_longhand_properties {
		property := property_id_from_longhand_index(index) or { panic('missing longhand ${index}') }
		assert int(property) == int(first_longhand_property_id()) + index
	}
	for name, property in {
		'text-box-trim': PropertyID.text_box_trim
		'text-box-edge': PropertyID.text_box_edge
	} {
		assert property_id_from_string(name) or { panic(name) } == property
		assert string_from_property_id(property) == name
		assert property_affects_layout(property)
		assert property in generated_expanded_longhands_for_shorthand(.all)
	}
	assert property_initial_value_string(.text_box_trim) == 'none'
	assert property_initial_value_string(.text_box_edge) == 'auto'
	assert !is_inherited_property(.text_box_trim)
	assert is_inherited_property(.text_box_edge)
	for value in ['none', 'trim-start', 'trim-end', 'trim-both'] {
		assert parse_css_value_logic(.text_box_trim, value) or { panic(value) }.serialize(.normal) == value
	}
	for value in ['auto', 'text', 'cap', 'ex', 'cap alphabetic', 'text alphabetic', 'cap text',
		'ex alphabetic'] {
		assert parse_css_value_logic(.text_box_edge, value) or { panic(value) }.serialize(.normal) == value
	}
	for value in ['', 'both', 'trim-start trim-end', 'none trim-both', '1', '"trim-both"'] {
		assert parse_css_value_logic(.text_box_trim, value) == none
	}
	for value in ['', 'alphabetic', 'auto text', 'cap cap', 'text ex', 'cap alphabetic text', '1',
		'cap, text', 'ideographic-ink'] {
		assert parse_css_value_logic(.text_box_edge, value) == none
	}
}

fn test_computed_text_box_edges_keep_over_and_under_independent() {
	mut style := ComputedProperties.new()
	assert style.text_box_trim() == .none_
	assert style.text_box_edge() == TextBoxEdge{}
	style.set_property_without_modifying_flags(.text_box_trim, &dom.StyleValue{ css_text: 'trim-both' })
	style.set_property_without_modifying_flags(.text_box_edge, &dom.StyleValue{ css_text: 'cap alphabetic' })
	assert style.text_box_trim() == .trim_both
	assert style.text_box_edge().over == .cap
	assert style.text_box_edge().alphabetic_under
	style.set_property_without_modifying_flags(.text_box_edge, &dom.StyleValue{ css_text: 'ex' })
	assert style.text_box_edge().over == .ex
	assert !style.text_box_edge().alphabetic_under
}
