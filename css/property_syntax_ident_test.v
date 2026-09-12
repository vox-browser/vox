module css

fn property_syntax_registration_succeeds(syntax string, initial_value string) bool {
	register_property(PropertyDefinition{
		name: '--syntax-test'
		syntax: syntax
		inherits: false
		initial_value: initial_value
	}) or { return false }
	return true
}

fn parse_property_syntax_test_value(syntax_text string, value_text string) StyleValue {
	syntax := parse_as_syntax(Parser.from_css_text(syntax_text).component_values) or {
		panic('failed to parse syntax')
	}
	return parse_with_a_syntax(Parser.from_css_text(value_text).component_values, syntax)
}

fn test_registered_property_syntax_rejects_reserved_idents() {
	assert !property_syntax_registration_succeeds('default', 'default')
	assert !property_syntax_registration_succeeds('Initial', 'Initial')
	assert !property_syntax_registration_succeeds('<custom-ident>', 'inherit')
}

fn test_registered_property_syntax_idents_are_case_sensitive() {
	assert property_syntax_registration_succeeds('Brand', 'Brand')
	assert !property_syntax_registration_succeeds('Brand', 'brand')
}

fn test_general_syntax_idents_remain_case_insensitive() {
	value := parse_property_syntax_test_value('Brand', 'brand')
	assert value is CustomIdentStyleValue
	assert value.serialize(.normal) == 'Brand'
}
