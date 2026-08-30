module css

fn test_mutable_computed_values_replace_and_inherit_slots() {
	mut source := MutableComputedValuesFacade.new()
	source.set_accent_color('red')
	source.set_width('12px')
	mut target := MutableComputedValuesFacade.new()
	target.inherit_from(source)
	assert target.values['accent-color'] == 'red'
	assert target.values['width'] == '12px'
}

fn test_computed_values_clone_does_not_alias_slots() {
	mut values := CSSComputedValuesFacade.new()
	values.values['background-color'] = 'blue'
	clone := values.clone_inherited_values()
	values.values['background-color'] = 'red'
	assert clone.background_color() == 'blue'
}

fn test_parser_and_token_stream_entry_points_preserve_state() {
	mut parser := CSSParserFacade.from_text('10px')
	result := parser.parse_length_percentage()
	assert result.accepted
	assert result.component_count == 1
	assert parser.history == ['parse_length_percentage']

	mut stream := CSSTokenStreamFacade.of_single_token('ident')
	assert stream.begin_transaction() == 0
	assert stream.current_index() == 0
	assert stream.current_token() == 'ident'
	assert stream.dump_all_tokens() == 'ident'
}

fn test_calculation_entry_points_apply_numeric_operation() {
	node := CalculationNodeFacade{
		kind: 'sum'
		operands: [1.0, 2.0, 3.0]
	}
	result := node.run_operation_if_possible()
	assert result.value() == 6.0
	assert result.negated().value() == -6.0
}

fn test_rule_and_font_entry_points_retain_observable_state() {
	mut rule := CSSRuleFacade.create()
	rule.set_property_style_value('color', 'red')
	rule.set_declarations_from_text('width: 10px; height: 20px')
	assert rule.get_direct_property('color') == 'red'
	assert rule.serialize_a_css_value('width') == '10px'
	assert rule.custom_property_count() == 0

	mut fonts := CSSFontFacade.new()
	fonts.set_onloading('listener')
	fonts.load_fonts_from_sheet(['Example'])
	assert fonts.onloading() == 'listener'
	assert fonts.loading_fonts() == ['Example']
}

fn test_value_and_namespace_entry_points_are_deterministic() {
	value := CSSValueFacade.create('10px')
	assert value.serialize() == '10px'
	assert value.snake_case() == '10px'
	assert add_length_percentages() == 0.0
	assert parse_css_type() == 'parse_css_type'
}
