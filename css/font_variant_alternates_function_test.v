module css

fn test_font_variant_alternates_uses_generic_function_values() {
	parsed := parse_css_value_logic(.font_variant_alternates, 'stylistic(flourish) styleset(display, titling) historical-forms') or {
		panic('font-variant-alternates did not parse')
	}
	assert parsed.serialize(.normal) == 'stylistic(flourish) historical-forms styleset(display, titling)'
	assert parsed is StyleValueList
	values := (parsed as StyleValueList).values()
	assert values[0] is FunctionStyleValue
	stylistic := values[0] as FunctionStyleValue
	assert stylistic.name() == 'stylistic'
	stylistic_names := stylistic.value()
	assert stylistic_names is StyleValueList
	assert (stylistic_names as StyleValueList).separator() == .comma

	mut computed := ComputedProperties.new()
	computed.set_property_without_modifying_flags(.font_variant_alternates, dom_style_value_from_value_logic(parsed))
	alternates := computed.font_variant_alternates() or {
		panic('font feature data did not retain the alternates')
	}
	assert alternates.historical_forms
	assert alternates.font_feature_value_entries == [
		FontFeatureValueKey{ type_: .stylistic, name: 'flourish' },
		FontFeatureValueKey{ type_: .styleset, name: 'display' },
		FontFeatureValueKey{ type_: .styleset, name: 'titling' },
	]
}

fn test_font_feature_value_type_from_string_recognizes_function_names() {
	assert font_feature_value_type_from_string('stylistic')? == .stylistic
	assert font_feature_value_type_from_string('styleset')? == .styleset
	assert font_feature_value_type_from_string('character-variant')? == .character_variant
	assert font_feature_value_type_from_string('swash')? == .swash
	assert font_feature_value_type_from_string('ornaments')? == .ornaments
	assert font_feature_value_type_from_string('annotation')? == .annotation
	assert font_feature_value_type_from_string('unknown') == none
}
