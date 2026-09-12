module css

fn parse_registered_syntax_value(syntax_text string, value_text string) StyleValue {
	syntax := parse_as_syntax(Parser.from_css_text(syntax_text).component_values) or {
		panic('failed to parse syntax')
	}
	return parse_with_a_syntax(Parser.from_css_text(value_text).component_values, syntax)
}

fn test_syntax_alternatives_skip_partial_single_value_match() {
	value := parse_registered_syntax_value('<integer> | <integer>+', '1 2')
	assert value is StyleValueList
	assert value.serialize(.normal) == '1 2'
}

fn test_syntax_alternatives_skip_partial_space_list_match() {
	value := parse_registered_syntax_value('<integer>+ | <integer>#', '1, 2')
	assert value is StyleValueList
	assert value.serialize(.normal) == '1, 2'
}
