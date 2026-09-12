module css

fn test_parser_collects_nested_arbitrary_substitution_function_presence() {
	values := parse_component_values_for_value_logic('calc(1px + var(--x)) [ENV(foo)] { inherit(--y, attr(data-x)) } if(style(--a): 1px)')
	mut presence := SubstitutionFunctionsPresence{}
	collect_arbitrary_substitution_function_presence(values, mut presence)

	assert presence.attr
	assert presence.env
	assert presence.if_
	assert presence.inherit
	assert presence.var
}

fn test_parser_ignores_non_substitution_function_names() {
	values := parse_component_values_for_value_logic('variable(--x) environment(foo)')
	mut presence := SubstitutionFunctionsPresence{}
	collect_arbitrary_substitution_function_presence(values, mut presence)

	assert !presence.has_any()
}
