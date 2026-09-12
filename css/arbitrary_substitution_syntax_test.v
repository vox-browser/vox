module css

fn test_property_parser_validates_substitution_function_argument_grammar() {
	valid := parse_css_value_logic(.width, 'calc(var(--fallback) + 1px)') or {
		panic('valid substitution function was rejected')
	}
	assert valid is UnresolvedStyleValue

	for invalid in ['var(,)', 'attr()', 'inherit(!!, 1px)', 'if()'] {
		assert parse_css_value_logic(.width, invalid) == none, invalid
	}
}

fn test_universal_syntax_validates_substitution_function_argument_grammar() {
	universal := SyntaxNode.create_universal()
	assert parse_with_a_syntax(parse_component_values_for_value_logic('var(--fallback)'), universal).type_() == .unresolved
	assert parse_with_a_syntax(parse_component_values_for_value_logic('var(,)'), universal).type_() == .guaranteed_invalid
}

fn test_function_parameter_default_rejects_invalid_substitution_syntax() {
	assert parse_css_rule_with_params(ParsingParams{}, '@function --valid(--x: var(--fallback)) { }') != none
	assert parse_css_rule_with_params(ParsingParams{}, '@function --invalid(--x: var(, 1px)) { }') == none
}

fn test_typed_om_rejects_invalid_unparsed_substitution_syntax() {
	value := CSSUnparsedValue.create([CSSUnparsedSegment('var(,)')])
	value.create_an_internal_representation(PropertyNameAndID.from_id(.width), .yes) or {
		assert err.msg().contains('TypeError')
		return
	}
	assert false, 'CSSUnparsedValue must reject invalid substitution syntax'
}
