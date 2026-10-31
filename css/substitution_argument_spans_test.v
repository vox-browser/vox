module css

import dom

fn test_private_name_argument_spans_preserve_owned_grammar_results() {
	for source, has_fallback in {
		'--value': false
		' --value ': false
		'--value,': true
		' --value , red ': true
		'--value,red,blue': true
		'var(--name), outer([a], {b:c;!})': true
		' ,red': true
	} {
		values := parse_component_values_for_value_logic(source)
		spans := parse_substitution_name_argument_spans(values)?
		assert (spans.second_argument != none) == has_fallback
		for kind in [ArbitrarySubstitutionFunction.var_, .inherit] {
			arguments := parse_according_to_argument_grammar(kind, values)?
			owned := arbitrary_arguments_as_declaration_value_list(arguments)?
			assert spans.first_argument == owned.first()
			assert spans.second_argument == owned.get(1)
		}
		assert parser_component_values_original_text(values) == source
	}
	for source in ['', ',red', '!bad', '--value;red', '--value !bad',
		'--value,red;bad', '--value,red !bad'] {
		values := parse_component_values_for_value_logic(source)
		assert parse_substitution_name_argument_spans(values) == none
		for kind in [ArbitrarySubstitutionFunction.var_, .inherit] {
			assert parse_according_to_argument_grammar(kind, values) == none
		}
	}
	for source in ['var( ,red)', 'inherit( ,red)'] {
		assert parser_component_values_original_text(substitute_arbitrary_substitution_functions(
			parse_component_values_for_value_logic(source), none)) == 'red'
	}
}

fn test_private_declaration_spans_preserve_cursor_failure_and_eof_rules() {
	mut borrowed := ParserTokenStream.from_source('skip good !bad', 'utf-8')
	borrowed.discard_a_token()
	borrowed.discard_whitespace()
	borrowed.mark()
	mut owned := borrowed
	span := parse_declaration_value_span(mut borrowed, none)?
	copy := parse_declaration_value(mut owned, none)?
	assert span == copy
	assert parser_component_values_original_text(span) == 'good '
	assert borrowed.index == owned.index
	assert borrowed.next_token().is_delim(u32(`!`))
	assert borrowed.marks == owned.marks
	for source in ['', ',red', '!bad', ';bad'] {
		mut stream := ParserTokenStream.from_source(source, 'utf-8')
		assert parse_declaration_value_span(mut stream, .comma) == none
		assert stream.index == 0
	}
	mut terminal := parse_component_values_for_value_logic('--value,red')
	terminal << ComponentValue.from_token(Token.create(.end_of_file, ''))
	terminal_spans := parse_substitution_name_argument_spans(terminal)?
	assert parser_component_values_original_text(terminal_spans.second_argument?) == 'red'
	mut fallback_interior := parse_component_values_for_value_logic('--missing,red')
	fallback_interior << ComponentValue.from_token(Token.create(.end_of_file, ''))
	fallback_interior << parse_component_values_for_value_logic(' !bad')
	fallback_spans := parse_substitution_name_argument_spans(fallback_interior)?
	assert parser_component_values_original_text(fallback_spans.first_argument) == '--missing'
	assert parser_component_values_original_text(fallback_spans.second_argument?) == 'red'
	for kind in [ArbitrarySubstitutionFunction.var_, .inherit] {
		public_arguments := arbitrary_arguments_as_declaration_value_list(
			parse_according_to_argument_grammar(kind, fallback_interior)?)?
		assert public_arguments.first() == fallback_spans.first_argument
		assert public_arguments.get(1) == fallback_spans.second_argument
	}
	mut interior := parse_component_values_for_value_logic('--value')
	interior << ComponentValue.from_token(Token.create(.end_of_file, ''))
	interior << parse_component_values_for_value_logic(',ignored !bad')
	spans := parse_substitution_name_argument_spans(interior)?
	assert parser_component_values_original_text(spans.first_argument) == '--value'
	assert spans.second_argument == none
	owned_arguments := arbitrary_arguments_as_declaration_value_list(
		parse_according_to_argument_grammar(.var_, interior)?)?
	assert owned_arguments.first() == spans.first_argument
	assert owned_arguments.get(1) == none
	// The substitution precheck still examines the whole input, even after EOF.
	terminal << ComponentValue.from_guaranteed_invalid(GuaranteedInvalidValue{})
	call := ComponentValue.from_function(Function{name: 'var', value: terminal})
	assert contains_guaranteed_invalid_value(substitute_arbitrary_substitution_functions([call], none))
}

fn test_private_name_argument_spans_preserve_nested_validation_and_token_payloads() {
	invalid := ComponentValue.from_token(Token.create(.bad_string, 'bad'))
	for nested in [ComponentValue.from_function(Function{name: 'f', value: [invalid]}),
		ComponentValue.from_block(SimpleBlock{value: [invalid]})] {
		mut values := parse_component_values_for_value_logic('--value,')
		values << nested
		assert parse_substitution_name_argument_spans(values) == none
		assert parse_according_to_argument_grammar(.var_, values) == none
		mut stream := ParserTokenStream.from_values([nested])
		assert parse_declaration_value_span(mut stream, none) == none
		assert stream.index == 0
	}
	mut values := parse_component_values_for_value_logic('--value,red [blue]')
	values[2].set_attr_tainted()
	mut token := values[2].token()
	token.start_position_.column += 17
	values[2] = ComponentValue.from_token(token)
	values[2].set_attr_tainted()
	spans := parse_substitution_name_argument_spans(values)?
	fallback := spans.second_argument?
	assert fallback == values[2..]
	assert fallback[0].contains_attr_tainted_value()
	assert fallback[0].token().start_position_.column == token.start_position_.column
	assert parser_component_values_original_text(values) == '--value,red [blue]'
}

fn test_owned_argument_api_and_substitution_outputs_remain_independent() {
	for kind in [ArbitrarySubstitutionFunction.var_, .inherit] {
		mut values := []ComponentValue{cap: 32768}
		values << parse_component_values_for_value_logic('--missing,red')
		arguments := parse_according_to_argument_grammar(kind, values)?
		mut owned := arbitrary_arguments_as_declaration_value_list(arguments)?
		assert owned.values[0].cap <= 16
		assert owned.values[1].cap <= 16
		owned.values[0][0] = ComponentValue.new('changed')
		owned.values[1][0].set_attr_tainted()
		assert values[0].is_ident('--missing')
		assert !values[2].contains_attr_tainted_value()
		assert parser_component_values_original_text(values) == '--missing,red'
	}
	for name in ['var', 'inherit'] {
		mut function := parse_component_values_for_value_logic('${name}(--missing,red [blue])')[0].function()
		function.value[2].set_attr_tainted()
		arguments := function.value
		input := [ComponentValue.from_function(function)]
		assert parser_component_values_original_text(input) == '${name}(--missing,red [blue])'
		mut output := substitute_arbitrary_substitution_functions(input, none)
		assert parser_component_values_original_text(output) == 'red [blue]'
		assert output[0].contains_attr_tainted_value()
		output[0] = ComponentValue.new('changed')
		mut block := output[2].block()
		block.value[0] = ComponentValue.new('changed-block')
		assert arguments[2].is_ident('red')
		assert arguments[4].block().value[0].is_ident('blue')
		assert parser_component_values_original_text(input) == '${name}(--missing,red [blue])'
		assert substitute_arbitrary_substitution_functions(
			parse_component_values_for_value_logic('${name}(--missing,)'), none).len == 0
	}
}

fn test_private_argument_dispatch_preserves_dynamic_names_and_local_scope_order() {
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
		'var(var(--name))': 'red'
		'inherit(var(--name))': 'blue'
		'var(--missing,outer([a],var(--value)))': 'outer([a],red)'
		'inherit(--missing,var(--value))': 'red'
	} {
		mut contexts := GuardedSubstitutionContexts{}
		input := parse_component_values_for_value_logic(source)
		actual := substitute_arbitrary_substitution_functions_for_element(element, mut contexts, input, none)
		assert parser_component_values_original_text(actual) == expected
		assert parser_component_values_original_text(input) == source
		assert contexts.contexts.len == 0
	}
	outer := &FunctionLocalScope{function_identity: 101,
		values: {'--value': FunctionLocalValue{tokens: parse_component_values_for_value_logic('outer')}}}
	inner := &FunctionLocalScope{function_identity: 102,
		values: {'--value': FunctionLocalValue{tokens: parse_component_values_for_value_logic('inner')}}}
	mut contexts := GuardedSubstitutionContexts{function_local_scopes: [outer, inner]}
	for source, expected in {'var(--value)': 'inner', 'inherit(--value)': 'outer'} {
		input := parse_component_values_for_value_logic(source)
		actual := substitute_arbitrary_substitution_functions_for_element(element, mut contexts, input, none)
		assert parser_component_values_original_text(actual) == expected
		assert contexts.function_local_scopes.len == 2
		assert contexts.function_local_scopes[0] == outer
		assert contexts.function_local_scopes[1] == inner
		assert contexts.contexts.len == 0
	}
}

fn test_private_argument_dispatch_keeps_validation_before_cycles_and_releases_guards() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := dom.AbstractElement.new(document.create_element('div')!, none)
	element.set_custom_property_data(dom.CSSCustomPropertyData_.create({
		'--a': dom.CSSCustomProperty_{value: custom_property_bridge_value(parse_custom_property_value('var(--b)'))}
		'--b': dom.CSSCustomProperty_{value: custom_property_bridge_value(parse_custom_property_value('var(--a)'))}
	}, none))
	mut contexts := GuardedSubstitutionContexts{}
	mut enclosing := SubstitutionContext{dependency_type: .property, first: '--a'}
	contexts.guard(mut enclosing)
	invalid_grammar := parse_component_values_for_value_logic('var(--a,red !bad)')
	invalid := substitute_arbitrary_substitution_functions_for_element(element, mut contexts,
		invalid_grammar, none)
	assert contains_guaranteed_invalid_value(invalid)
	assert contexts.contexts.len == 1
	assert !contexts.contexts[0].is_cyclic
	valid_grammar := parse_component_values_for_value_logic('var(--a)')
	cyclic := substitute_arbitrary_substitution_functions_for_element(element, mut contexts,
		valid_grammar, none)
	assert contains_guaranteed_invalid_value(cyclic)
	assert contexts.contexts.len == 1
	assert contexts.contexts[0].is_cyclic
	contexts.unguard(enclosing)
	assert contexts.contexts.len == 0
	uncached := substitute_arbitrary_substitution_functions_for_element(element, mut contexts,
		valid_grammar, none)
	assert contains_guaranteed_invalid_value(uncached)
	assert contexts.contexts.len == 0
	assert parser_component_values_original_text(valid_grammar) == 'var(--a)'
}
