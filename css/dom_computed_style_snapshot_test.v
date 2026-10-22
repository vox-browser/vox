module css

fn test_dom_computed_style_default_snapshot_keeps_bridge_handle() {
	computed := ComputedProperties.new()
	snapshot := computed_properties_to_dom(computed)
	assert snapshot.scrollbar_width() == 'auto'
	assert snapshot.view_transition_name() == none
	assert snapshot.anchor_names().len == 0
	assert snapshot.color_schemes().len == 0
	assert !snapshot.color_scheme_only()
	assert snapshot.css_handle == voidptr(computed)
}

fn test_dom_computed_style_snapshot_owns_rare_values_across_source_updates() {
	mut computed := ComputedProperties.new()
	mut schemes := ['light'.clone(), 'dark'.clone()]
	computed.set_property_without_modifying_flags(.color_scheme,
		dom_style_value_from_value_logic(StyleValue(ColorSchemeStyleValue.create(schemes, true))))
	computed.set_property_without_modifying_flags(.anchor_name,
		dom_style_value_from_value_logic(StyleValue(CustomIdentStyleValue.create('--first'))))
	computed.set_property_without_modifying_flags(.view_transition_name,
		dom_style_value_from_value_logic(StyleValue(CustomIdentStyleValue.create('first'))))
	first := computed_properties_to_dom(computed)
	assert first.color_scheme_only()
	assert first.color_schemes() == ['light', 'dark']
	assert first.anchor_names() == ['--first']
	assert first.view_transition_name()? == 'first'
	// ColorSchemeStyleValue deliberately borrows this vector. A DOM snapshot
	// must retain its previous values when that typed source changes in place.
	schemes[0] = 'custom'
	computed.set_property_without_modifying_flags(.anchor_name,
		dom_style_value_from_value_logic(StyleValue(CustomIdentStyleValue.create('--second'))))
	computed.set_property_without_modifying_flags(.view_transition_name,
		dom_style_value_from_value_logic(StyleValue(CustomIdentStyleValue.create('second'))))
	second := computed_properties_to_dom(computed)
	assert first.css_handle == second.css_handle && first.css_handle == voidptr(computed)
	assert first.color_schemes() == ['light', 'dark']
	assert first.anchor_names() == ['--first']
	assert first.view_transition_name()? == 'first'
	assert second.color_schemes() == ['custom', 'dark']
	assert second.anchor_names() == ['--second']
	assert second.view_transition_name()? == 'second'
	computed.set_property_without_modifying_flags(.color_scheme,
		dom_style_value_from_value_logic(StyleValue(ColorSchemeStyleValue.normal())))
	computed.set_property_without_modifying_flags(.anchor_name,
		dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.none_))))
	computed.set_property_without_modifying_flags(.view_transition_name,
		dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.none_))))
	third := computed_properties_to_dom(computed)
	assert third.color_schemes().len == 0 && third.anchor_names().len == 0
	assert third.view_transition_name() == none && !third.color_scheme_only()
	assert first.color_schemes() == ['light', 'dark']
	assert second.view_transition_name()? == 'second'
}
