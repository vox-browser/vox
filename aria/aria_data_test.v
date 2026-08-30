module aria

import dom

fn aria_data_test_element(document &dom.Document, name string) &dom.Element {
	return dom.create_element(document, name, 'http://www.w3.org/1999/xhtml', none, none, false) or {
		panic(err)
	}
}

fn test_aria_data_parses_values_defaults_and_idrefs() {
	document := dom.Document.create(dom.url_about_blank())
	root := aria_data_test_element(document, 'div')
	owner := aria_data_test_element(document, 'div')
	target := aria_data_test_element(document, 'span')
	mut target_mut := unsafe { &dom.Element(target) }
	target_mut.set_attribute_value('id', 'target')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(owner.as_node())!
	root_node.append_child(target.as_node())!

	mut mixin := ARIAMixin.create(owner, none, none)
	mixin.set_aria_atomic('true')
	mixin.set_aria_auto_complete('both')
	mixin.set_aria_checked('mixed')
	mixin.set_aria_col_count('-1')
	mixin.set_aria_controls('target missing')
	mixin.set_aria_current('page')
	mixin.set_aria_drop_effect('none copy move')
	mixin.set_aria_expanded('false')
	mixin.set_aria_has_popup('dialog')
	mixin.set_aria_live('polite')
	mixin.set_aria_orientation('vertical')
	mixin.set_aria_relevant('additions removals text')
	mixin.set_aria_value_max(' 12.5 ')
	data := AriaData.from_mixin(mixin)
	assert data.aria_atomic_or_default()
	assert data.aria_auto_complete_or_default() == .both
	assert data.aria_checked_or_default() == .mixed
	assert data.aria_col_count_or_default()? == -1
	assert data.aria_controls_or_default() == ['target']
	assert data.aria_current_or_default() == .page
	assert data.aria_drop_effect_or_default() == [.copy, .move]
	assert data.aria_expanded_or_default()? == false
	assert data.aria_has_popup_or_default() == .dialog
	assert data.aria_live_or_default() == .polite
	assert data.aria_orientation_or_default() == .vertical
	assert data.aria_relevant_or_default() == [.all]
	assert data.aria_value_max_or_default()? == 12.5
	assert data.aria_value_min_or(4.0)? == 4.0
}

fn test_state_and_property_string_serialization() {
	data := AriaData{}
	assert state_or_property_from_string('aria-valuenow')? == .aria_value_now
	assert state_or_property_to_string(.aria_active_descendant) == 'aria-activedescendant'
	assert tristate_to_string(.mixed) == 'mixed'
	assert optional_bool_to_string(none) == 'undefined'
	assert optional_integer_to_string(none) == ''
	assert state_or_property_to_string_value(.aria_atomic, &data, DefaultValue(true)) == 'true'
	assert state_or_property_to_string_value(.aria_live, &data, DefaultValue(AriaLive.assertive)) == 'assertive'
	assert state_or_property_to_string_value(.aria_orientation, &data,
		DefaultValue(AriaOrientation.horizontal)) == 'horizontal'
	// RoleType.cpp currently does not apply an implicit role default to aria-haspopup.
	assert state_or_property_to_string_value(.aria_has_popup, &data,
		DefaultValue(AriaHasPopup.listbox)) == 'false'
}

fn test_aria_data_exact_parser_entry_points_match_upstream_semantics() {
	assert AriaData.parse_true_false('true')
	assert !AriaData.parse_true_false('TRUE')
	assert AriaData.parse_tristate('mixed') == .mixed
	assert AriaData.parse_tristate(none) == .undefined
	assert AriaData.parse_true_false_undefined('false')? == false
	assert AriaData.parse_true_false_undefined('undefined') == none
	assert AriaData.parse_optional_true_false('true')? == true
	assert AriaData.parse_integer('-2147483648')? == i32(-2147483648)
	assert AriaData.parse_integer('1.5') == none
	assert AriaData.parse_number(' 12.5 ')? == 12.5
	assert AriaData.parse_aria_autocomplete('inline') == .inline
	assert AriaData.parse_aria_current('unknown') == .false_
	assert AriaData.parse_aria_drop_effect('copy unknown move') == [.copy, .move]
	assert AriaData.parse_aria_drop_effect('unknown') == [.none_]
	assert AriaData.parse_aria_has_popup('menu') == .menu
	assert AriaData.parse_aria_invalid('grammar') == .grammar
	assert AriaData.parse_aria_live('assertive')? == .assertive
	assert AriaData.parse_aria_orientation('horizontal')? == .horizontal
	assert AriaData.parse_aria_relevant('additions removals text') == [.all]
	assert AriaData.parse_aria_sort('descending') == .descending
}

fn test_aria_data_build_data_is_the_constructor_logic() {
	document := dom.Document.create(dom.url_about_blank())
	element := aria_data_test_element(document, 'div')
	mut mixin := ARIAMixin.create(element, none, none)
	mixin.set_aria_busy('true')
	mixin.set_aria_value_now('7.25')
	data := AriaData.build_data(mixin)
	assert data.aria_busy_or_default()
	assert data.aria_value_now_or_default()? == 7.25
}
