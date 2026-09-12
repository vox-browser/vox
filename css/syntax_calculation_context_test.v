module css

fn test_length_percentage_syntax_sets_calculation_context() {
	syntax := parse_as_syntax(syntax_component_values_from_string('<length-percentage>')) or {
		panic('failed to parse syntax')
	}
	value_components := Parser.from_css_text('calc(10% + 10px)').component_values
	value := parse_with_a_syntax(value_components, syntax)
	assert value is CalculatedStyleValue
	if value is CalculatedStyleValue {
		assert value.calculation_context.percentages_resolve_as? == .length
	}
}
