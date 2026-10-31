module css

import dom

fn flattening_test_fallback(count int) ComponentValue {
	mut arguments := [ComponentValue.from_token(Token.create_ident('--missing', '--missing')),
		ComponentValue.from_token(Token.create(.comma, ','))]
	leaf := ComponentValue.from_token(Token.create_ident('a', 'a'))
	arguments << []ComponentValue{len: count, init: leaf}
	return ComponentValue.from_function(Function{name: 'var', value: arguments})
}

fn test_flattened_substitutions_keep_each_expansion_limit_separate_from_output_prefix() {
	call := flattening_test_fallback(10000)
	result := substitute_arbitrary_substitution_functions([call, call], none)
	// Each expansion fits the existing bound, even though their total does not.
	assert result.len == 20000
	assert !contains_guaranteed_invalid_value(result)
	assert result[0].is_ident('a') && result[result.len - 1].is_ident('a')
	assert call.function().value.len == 10002
}

fn test_flattened_substitution_failure_counts_remaining_source_and_releases_guard() {
	mut values := [flattening_test_fallback(10000)]
	values << []ComponentValue{len: 6385, init: ComponentValue.new('tail')}
	context := SubstitutionContext{dependency_type: .property, first: '--outer'}
	mut guarded := GuardedSubstitutionContexts{}
	result := substitute_arbitrary_substitution_functions_with_optional_element(none,
		mut guarded, values, context)
	assert contains_guaranteed_invalid_value(result)
	assert guarded.contexts.len == 0
	assert values.len == 6386
	assert values[0].function().value.len == 10002
	valid := substitute_arbitrary_substitution_functions_with_optional_element(none,
		mut guarded, parse_component_values_for_value_logic('ok'), context)
	assert valid.len == 1 && valid[0].is_ident('ok')
	assert guarded.contexts.len == 0
}

fn test_flattened_substitution_preserves_empty_invalid_and_independent_nested_children() {
	assert substitute_arbitrary_substitution_functions(
		parse_component_values_for_value_logic('var(--missing,)'), none).len == 0
	assert contains_guaranteed_invalid_value(substitute_arbitrary_substitution_functions(
		parse_component_values_for_value_logic('var(--missing)'), none))
	empty := substitute_arbitrary_substitution_functions(
		parse_component_values_for_value_logic('start var(--missing,) end'), none)
	assert parser_component_values_original_text(empty) == 'start  end'
	source_text := 'outer(red [blue] var(--missing, green))'
	source := parse_component_values_for_value_logic(source_text)
	result := substitute_arbitrary_substitution_functions(source, none)
	assert parser_component_values_original_text(result) == 'outer(red [blue]  green)'
	mut function := result[0].function()
	function.value[0] = ComponentValue.new('changed')
	mut block := function.value[2].block()
	block.value[0] = ComponentValue.new('changed-block')
	assert parser_component_values_original_text(source) == source_text
	assert source[0].function().value[0].is_ident('red')
	assert source[0].function().value[2].block().value[0].is_ident('blue')
}

fn test_flattened_property_tokens_preserve_taint_and_return_independent_public_output() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	target := document.create_element('div')!
	element := dom.AbstractElement.new(target, none)
	mut tokens := parse_component_values_for_value_logic('red blue')
	tokens[0].set_attr_tainted()
	stored := dom_style_value_from_value_logic(StyleValue(
		UnresolvedStyleValue.create_with_presence(tokens, SubstitutionFunctionsPresence{}, none)))
	element.set_custom_property_data(dom.CSSCustomPropertyData_.create({
		'--value': dom.CSSCustomProperty_{value: custom_property_bridge_value(stored)}
	}, none))
	mut guarded := GuardedSubstitutionContexts{}
	mut result := substitute_arbitrary_substitution_functions_for_element(element, mut guarded,
		parse_component_values_for_value_logic('var(--value)'), none)
	assert result[0].contains_attr_tainted_value()
	assert !result[2].contains_attr_tainted_value()
	result[2].set_attr_tainted()
	result[0] = ComponentValue.new('changed')
	assert tokens[0].is_ident('red')
	assert !tokens[2].contains_attr_tainted_value()
	assert guarded.contexts.len == 0
}

fn test_substitution_name_borrowing_keeps_dynamic_names_and_function_local_ownership() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	parent := document.create_element('div')!
	target := document.create_element('span')!
	mut parent_node := parent.as_node()
	parent_node.append_child(target.as_node())!
	parent_element := dom.AbstractElement.new(parent, none)
	element := dom.AbstractElement.new(target, none)
	parent_data := dom.CSSCustomPropertyData_.create({
		'--value': dom.CSSCustomProperty_{value: custom_property_bridge_value(parse_custom_property_value('blue'))}
	}, none)
	parent_element.set_custom_property_data(parent_data)
	element.set_custom_property_data(dom.CSSCustomPropertyData_.create({
		'--name': dom.CSSCustomProperty_{value: custom_property_bridge_value(parse_custom_property_value('--value'))}
		'--value': dom.CSSCustomProperty_{value: custom_property_bridge_value(parse_custom_property_value('red'))}
	}, parent_data))
	for source, expected in {
		'var( --value )': 'red'
		'var(var(--name))': 'red'
		'inherit( --value )': 'blue'
		'inherit(var(--name))': 'blue'
		'var(--value extra, fallback)': ' fallback'
	} {
		mut contexts := GuardedSubstitutionContexts{}
		input := parse_component_values_for_value_logic(source)
		output := substitute_arbitrary_substitution_functions_for_element(element, mut contexts, input, none)
		assert parser_component_values_original_text(output) == expected
		assert parser_component_values_original_text(input) == source
		assert contexts.contexts.len == 0
	}
	scope := &FunctionLocalScope{
		function_identity: 42
		values: {'--value': FunctionLocalValue{tokens: parse_component_values_for_value_logic('local')}}
	}
	mut contexts := GuardedSubstitutionContexts{function_local_scopes: [scope]}
	local := computed_custom_property_tokens_for_substitution(element, '--value', mut contexts)?
	assert parser_component_values_original_text(local) == 'local'
	assert contexts.function_local_scopes.len == 1
	assert contexts.function_local_scopes[0] == scope
	assert contexts.contexts.len == 0
}
