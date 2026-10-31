module css

fn test_declaration_span_keeps_boundaries_and_independent_storage() {
	mut tokens := ParserTokenStream.from_source('skip a [b] func(c),tail', 'utf-8')
	tokens.discard_a_token()
	tokens.discard_whitespace()
	start := tokens.index
	mut value := parse_declaration_value(mut tokens, .comma) or { panic('missing value') }
	assert parser_component_values_original_text(value) == 'a [b] func(c)'
	assert tokens.next_token().is(.comma)
	assert tokens.index == start + value.len
	value[0] = ComponentValue.new('changed')
	assert tokens.values[start].is_ident('a')
	assert parser_component_values_original_text(tokens.values) == 'skip a [b] func(c),tail'
}

fn test_declaration_span_retains_failure_and_eof_behavior() {
	for source in ['', ';bad', '!important', ',fallback'] {
		mut tokens := ParserTokenStream.from_source(source, 'utf-8')
		if _ := parse_declaration_value(mut tokens, .comma) {
			assert false, 'invalid declaration prefix accepted'
		}
		assert tokens.index == 0
	}
	mut tokens := ParserTokenStream.from_source('good !bad', 'utf-8')
	value := parse_declaration_value(mut tokens, none) or { panic('missing prefix') }
	assert parser_component_values_original_text(value) == 'good '
	assert tokens.next_token().is_delim(u32(`!`))
	mut at_end := ParserTokenStream.from_source('last', 'utf-8')
	last := parse_declaration_value(mut at_end, none) or { panic('missing final value') }
	assert last.len == 1
	assert !at_end.has_next_token()
}

fn test_declaration_span_rejects_invalid_nested_values_without_consuming_them() {
	invalid := ComponentValue.from_token(Token.create(.bad_string, 'bad'))
	for nested in [ComponentValue.from_function(Function{name: 'f', value: [invalid]}),
		ComponentValue.from_block(SimpleBlock{value: [invalid]})] {
		mut tokens := ParserTokenStream.from_values([nested])
		if _ := parse_declaration_value(mut tokens, none) {
			assert false, 'invalid nested declaration accepted'
		}
		assert tokens.index == 0
	}
}

fn test_leaf_substitution_preserves_taint_and_has_independent_storage() {
	mut values := parse_component_values_for_value_logic('red 2px "中"')
	values[0].set_attr_tainted()
	mut result := substitute_arbitrary_substitution_functions(values, none)
	assert parser_component_values_original_text(result) == 'red 2px "中"'
	assert result[0].contains_attr_tainted_value()
	assert !result[2].contains_attr_tainted_value()
	result[2].set_attr_tainted()
	assert !values[2].contains_attr_tainted_value()
	result[0] = ComponentValue.new('changed')
	assert values[0].is_ident('red')
	assert substitute_arbitrary_substitution_functions([]ComponentValue{}, none).len == 0
	invalid := [ComponentValue.from_guaranteed_invalid(GuaranteedInvalidValue{})]
	assert contains_guaranteed_invalid_value(substitute_arbitrary_substitution_functions(invalid, none))
}

fn test_nested_substitution_keeps_input_and_fallback_values() {
	source := 'outer([var(--missing,red)] var(--missing,2px))'
	values := parse_component_values_for_value_logic(source)
	result := substitute_arbitrary_substitution_functions(values, none)
	assert parser_component_values_original_text(result) == 'outer([red] 2px)'
	assert parser_component_values_original_text(values) == source
	missing := parse_component_values_for_value_logic('var(--missing)')
	assert contains_guaranteed_invalid_value(substitute_arbitrary_substitution_functions(missing, none))
}

fn test_leaf_substitution_does_not_copy_spare_source_capacity() {
	mut values := []ComponentValue{cap: 32768}
	values << ComponentValue.from_token(Token.create_ident('red', 'red'))
	mut result := substitute_arbitrary_substitution_functions(values, none)
	assert result.len == 1
	assert result[0].is_ident('red')
	// A tiny live input must not copy a large retained allocation or unused slots.
	assert result.cap <= 16
	result[0] = ComponentValue.new('changed')
	assert values[0].is_ident('red')
}

fn test_leaf_substitution_still_applies_and_releases_cycle_guards() {
	values := parse_component_values_for_value_logic('red')
	context := SubstitutionContext{dependency_type: .property, first: '--color'}
	mut guarded := GuardedSubstitutionContexts{}
	mut active := context
	guarded.guard(mut active)
	cyclic := substitute_arbitrary_substitution_functions_with_optional_element(none,
		mut guarded, values, context)
	assert contains_guaranteed_invalid_value(cyclic)
	assert guarded.contexts.len == 1
	assert guarded.contexts[0].is_cyclic
	guarded.unguard(context)
	resolved := substitute_arbitrary_substitution_functions_with_optional_element(none,
		mut guarded, values, context)
	assert parser_component_values_original_text(resolved) == 'red'
	assert guarded.contexts.len == 0
}

fn test_leaf_substitution_retains_the_expansion_limit() {
	values := parse_component_values_for_value_logic('var(--missing,' + 'a '.repeat(8193) + ')')
	result := substitute_arbitrary_substitution_functions(values, none)
	assert contains_guaranteed_invalid_value(result)
	mut remainder := parse_component_values_for_value_logic('var(--missing,)')
	remainder << parse_component_values_for_value_logic('a '.repeat(8193))
	assert remainder.len > 16384
	assert contains_guaranteed_invalid_value(substitute_arbitrary_substitution_functions(remainder, none))
}
