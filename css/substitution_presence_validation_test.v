module css

import platform

// Keep the pre-change owning grammar as an independent oracle. In particular,
// this must not call parse_substitution_argument_spans or the public pair parser.
fn presence_validation_legacy_pair(mut tokens ParserTokenStream, separator TokenType) ?DeclarationValueList {
	first_argument := parse_declaration_value(mut tokens, separator) or { return none }
	if !tokens.has_next_token() {
		return DeclarationValueList{ values: [first_argument] }
	}
	if !tokens.next_token().is(separator) {
		return none
	}
	tokens.discard_a_token()
	second_argument := parse_declaration_value(mut tokens, none) or { []ComponentValue{} }
	return DeclarationValueList{ values: [first_argument, second_argument] }
}

fn presence_validation_legacy_grammar(kind ArbitrarySubstitutionFunction, values []ComponentValue) ?ArbitrarySubstitutionFunctionArguments {
	mut tokens := ParserTokenStream.from_values(values)
	match kind {
		.attr, .env, .inherit, .var_ {
			list := presence_validation_legacy_pair(mut tokens, .comma) or { return none }
			if tokens.has_next_token() {
				return none
			}
			return ArbitrarySubstitutionFunctionArguments(list)
		}
		.if_ {
			mut args := IfArgs{}
			for tokens.has_next_token() {
				branch := presence_validation_legacy_pair(mut tokens, .colon) or { break }
				args.branches << IfArgsBranch{
					condition: branch.first()
					value:     branch.get(1)
				}
				if !tokens.next_token().is(.semicolon) {
					break
				}
				tokens.discard_a_token()
			}
			if args.branches.len == 0 || tokens.has_next_token() {
				return none
			}
			return ArbitrarySubstitutionFunctionArguments(args)
		}
	}
}

fn presence_validation_legacy_optional(values []ComponentValue) bool {
	mut tokens := ParserTokenStream.from_values(values)
	tokens.discard_whitespace()
	if !tokens.has_next_token() {
		return true
	}
	_ := parse_declaration_value(mut tokens, none) or { return false }
	tokens.discard_whitespace()
	return !tokens.has_next_token()
}

fn presence_validation_assert_grammar(kind ArbitrarySubstitutionFunction, values []ComponentValue) {
	expected := presence_validation_legacy_grammar(kind, values)
	assert arbitrary_substitution_arguments_are_valid(kind, values) == (expected != none)
	if arguments := expected {
		actual := parse_according_to_argument_grammar(kind, values) or {
			panic('owning grammar rejected a legacy-valid argument list')
		}
		match arguments {
			DeclarationValueList {
				list := arbitrary_arguments_as_declaration_value_list(actual) or {
					panic('expected declaration values')
				}
				assert list.values == arguments.values
			}
			IfArgs {
				branches := arbitrary_arguments_as_if_args(actual) or {
					panic('expected if branches')
				}
				assert branches.branches == arguments.branches
			}
		}
	} else {
		assert parse_according_to_argument_grammar(kind, values) == none
	}
}

fn presence_validation_legacy_collect(values []ComponentValue, mut presence SubstitutionFunctionsPresence) ! {
	for value in values {
		if value.is_function() {
			function := value.function()
			if is_a_custom_property_name_string(function.name) {
				presence.custom_function = true
			}
			if kind := to_arbitrary_substitution_function(function.name) {
				_ := presence_validation_legacy_grammar(kind, function.value) or {
					return error('invalid arbitrary substitution function syntax')
				}
				match kind {
					.attr { presence.attr = true }
					.env { presence.env = true }
					.if_ { presence.if_ = true }
					.inherit { presence.inherit = true }
					.var_ { presence.var = true }
				}
			}
			presence_validation_legacy_collect(function.value, mut presence)!
		} else if value.is_block() {
			presence_validation_legacy_collect(value.block().value, mut presence)!
		}
	}
}

fn test_presence_validation_matches_prechange_argument_grammar() {
	for source in ['', ' ', '--value', ' --value ', '--value,', ' --value , red ', '--value,red,blue',
		',red', ' ,red', '!bad', '--value;red', '--value !bad', '--value,red;bad', '--value,red !bad',
		'var(--name), outer([a], {b:c;!})', 'a', 'a:', 'a:b', 'a:;', 'a:b;', 'a:b;c:d', 'a:b;c:d;',
		'a:b;;', 'a;b:c', ':b', ' :b', 'a:!bad', 'a:b;!bad', 'a:b;c'] {
		values := parse_component_values_for_value_logic(source)
		for kind in [ArbitrarySubstitutionFunction.attr, .env, .inherit, .var_, .if_] {
			presence_validation_assert_grammar(kind, values)
		}
		assert is_valid_optional_declaration_value(values) ==
			presence_validation_legacy_optional(values)
		assert parser_component_values_original_text(values) == source
	}
}

fn test_presence_validation_keeps_omitted_and_empty_fallbacks_distinct() {
	for kind in [ArbitrarySubstitutionFunction.attr, .env, .inherit, .var_] {
		omitted := arbitrary_arguments_as_declaration_value_list(parse_according_to_argument_grammar(kind,
			parse_component_values_for_value_logic('name'))?)?
		empty := arbitrary_arguments_as_declaration_value_list(parse_according_to_argument_grammar(kind,
			parse_component_values_for_value_logic('name,'))?)?
		assert omitted.get(1) == none
		assert empty.get(1)?.len == 0
	}
	omitted := arbitrary_arguments_as_if_args(parse_according_to_argument_grammar(.if_,
		parse_component_values_for_value_logic('condition'))?)?
	empty := arbitrary_arguments_as_if_args(parse_according_to_argument_grammar(.if_,
		parse_component_values_for_value_logic('condition:;'))?)?
	assert omitted.branches.len == 1
	assert omitted.branches[0].value == none
	assert empty.branches.len == 1
	assert empty.branches[0].value?.len == 0
	for source in ['condition', 'condition:', 'condition:;', 'a:b;c:d;'] {
		assert arbitrary_substitution_arguments_are_valid(.if_,
			parse_component_values_for_value_logic(source))
	}
	for source in ['', 'a;b:c', 'a:b;;', 'a:b;!bad'] {
		assert !arbitrary_substitution_arguments_are_valid(.if_,
			parse_component_values_for_value_logic(source))
	}
}

fn test_presence_validation_borrowed_pairs_preserve_cursor_and_marks() {
	for separator in [TokenType.comma, .colon] {
		for source in ['', 'name', 'name,', 'name,value !bad', 'name:value;next:last', ',bad',
			':bad', '!bad', 'name;bad', 'outer([a], {b:c;!}),value'] {
			values := parse_component_values_for_value_logic('skip ${source}')
			mut borrowed := ParserTokenStream.from_values(values)
			borrowed.discard_a_token()
			borrowed.discard_whitespace()
			borrowed.mark()
			mut owning := borrowed
			expected := presence_validation_legacy_pair(mut owning, separator)
			if actual := parse_substitution_argument_spans(mut borrowed, separator) {
				list := expected or { panic('borrowed grammar accepted a legacy-invalid pair') }
				assert actual.first_argument == list.first()
				assert actual.second_argument == list.get(1)
			} else {
				assert expected == none
			}
			assert borrowed.index == owning.index
			assert borrowed.marks == owning.marks
			assert borrowed.next_token() == owning.next_token()
			assert parser_component_values_original_text(values) == 'skip ${source}'
		}
	}
}

fn test_presence_validation_preserves_nested_errors_and_eof_boundaries() {
	for invalid_type in [TokenType.invalid, .bad_string, .bad_url, .function, .open_curly, .open_paren,
		.open_square, .close_curly, .close_paren, .close_square, .end_of_file] {
		invalid := ComponentValue.from_token(Token.create(invalid_type, 'bad'))
		for nested in [
			ComponentValue.from_function(Function{ name: 'f', value: [invalid] }),
			ComponentValue.from_block(SimpleBlock{ value: [invalid] }),
		] {
			for prefix in ['', 'name,', 'condition:'] {
				mut values := parse_component_values_for_value_logic(prefix)
				values << nested
				for kind in [ArbitrarySubstitutionFunction.attr, .env, .inherit, .var_, .if_] {
					presence_validation_assert_grammar(kind, values)
				}
				assert !is_valid_optional_declaration_value(values)
			}
		}
	}
	for prefix in ['', 'name', 'name,red', 'condition:blue;', 'name,'] {
		mut values := parse_component_values_for_value_logic(prefix)
		values << ComponentValue.from_token(Token.create(.end_of_file, ''))
		values << parse_component_values_for_value_logic(' !bad var()')
		for kind in [ArbitrarySubstitutionFunction.attr, .env, .inherit, .var_, .if_] {
			presence_validation_assert_grammar(kind, values)
		}
		assert is_valid_optional_declaration_value(values) ==
			presence_validation_legacy_optional(values)
	}
}

fn test_presence_validation_keeps_error_order_and_partial_flags() {
	for source in ['', 'red', 'calc(1px + var(--x)) [ENV(foo)]', '--custom(var(--x))',
		'attr(name) var(--x) inherit(--y) if(a:b)', 'var() env(foo)', 'attr(name) env()',
		'--custom(var())', 'var(--x, env())', 'var(--x, env(!))', 'var(--x ! env(foo))',
		'if(a:var();b:env(foo))', 'env(foo) [inherit()] var(--x)'] {
		values := parse_component_values_for_value_logic(source)
		mut expected := SubstitutionFunctionsPresence{ env: true }
		mut expected_error := ''
		presence_validation_legacy_collect(values, mut expected) or {
			expected_error = err.msg()
		}
		mut actual := SubstitutionFunctionsPresence{ env: true }
		mut actual_error := ''
		collect_arbitrary_substitution_function_presence(values, mut actual) or {
			actual_error = err.msg()
		}
		assert actual == expected
		assert actual_error == expected_error
		for value in values {
			mut expected_component := SubstitutionFunctionsPresence{ attr: true }
			mut expected_component_error := ''
			presence_validation_legacy_collect([value], mut expected_component) or {
				expected_component_error = err.msg()
			}
			mut actual_component := SubstitutionFunctionsPresence{ attr: true }
			mut actual_component_error := ''
			collect_arbitrary_substitution_function_presence_from_component(value,
				mut actual_component) or { actual_component_error = err.msg() }
			assert actual_component == expected_component
			assert actual_component_error == expected_component_error
		}
		assert parser_component_values_original_text(values) == source
	}
}

fn test_presence_validation_public_argument_buffers_remain_independently_owned() {
	for kind in [ArbitrarySubstitutionFunction.attr, .env, .inherit, .var_] {
		mut values := parse_component_values_for_value_logic('name,red')
		mut owned := arbitrary_arguments_as_declaration_value_list(parse_according_to_argument_grammar(kind, values)?)?
		owned.values[0][0] = ComponentValue.new('changed')
		owned.values[1][0].set_attr_tainted()
		assert values[0].is_ident('name')
		assert !values[2].contains_attr_tainted_value()
		values[2] = ComponentValue.new('blue')
		assert owned.values[1][0].is_ident('red')
		assert owned.values[1][0].contains_attr_tainted_value()
	}
	mut values := parse_component_values_for_value_logic('a:b;c:d')
	mut owned := arbitrary_arguments_as_if_args(parse_according_to_argument_grammar(.if_, values)?)?
	owned.branches[0].condition[0] = ComponentValue.new('changed')
	mut first_value := owned.branches[0].value?
	first_value[0].set_attr_tainted()
	assert values[0].is_ident('a')
	assert !values[2].contains_attr_tainted_value()
	values[4] = ComponentValue.new('other')
	assert owned.branches[1].condition[0].is_ident('c')
	assert parser_component_values_original_text(owned.branches[1].value?) == 'd'
}

fn test_presence_validation_does_not_copy_argument_sized_buffers() {
	$if !prealloc {
		return
	}
	space := ComponentValue.from_token(Token.create_whitespace(' '))
	mut values := []ComponentValue{len: 8193, init: space}
	values[values.len - 1] = ComponentValue.from_token(Token.create_ident('name', 'name'))
	// Warm the immutable EOF before entering the measured allocation scope.
	for kind in [ArbitrarySubstitutionFunction.attr, .env, .inherit, .var_, .if_] {
		assert arbitrary_substitution_arguments_are_valid(kind, values)
	}
	mut storage := platform.new_arena('substitution presence argument validation')
	entry := storage.enter()
	for _ in 0 .. 64 {
		for kind in [ArbitrarySubstitutionFunction.attr, .env, .inherit, .var_, .if_] {
			assert arbitrary_substitution_arguments_are_valid(kind, values)
		}
	}
	storage.leave(entry)
	assert storage.usage().used < i64(sizeof(ComponentValue)) * values.len
	storage.release()
	assert values[0].is(.whitespace)
	assert values.last().is_ident('name')
}
