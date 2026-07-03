module css

// Translation of Tests/LibWeb/TestCSSSyntaxParser.cpp.

fn delim_cv(c string) ComponentValue {
	return ComponentValue.from_token(Token.create_delim(u32(c.runes()[0]), c))
}

fn ident_cv(name string) ComponentValue {
	return ComponentValue.from_token(Token.create_ident(name, name))
}

fn string_cv(value string) ComponentValue {
	return ComponentValue.from_token(Token.create_string(value, value))
}

fn whitespace_cv() ComponentValue {
	return ComponentValue.from_token(Token.create_whitespace(' '))
}

// <name>
fn type_tokens(name string) []ComponentValue {
	return [delim_cv('<'), ident_cv(name), delim_cv('>')]
}

fn compare_dump(values []ComponentValue, expected string) {
	syntax := parse_as_syntax(values) or {
		assert false, 'parse_as_syntax returned none, expected a node'
		return
	}
	assert syntax.dump() == expected
}

fn expect_dumps_equal(lhs_values []ComponentValue, rhs_values []ComponentValue) {
	lhs := parse_as_syntax(lhs_values) or {
		assert false, 'lhs parse_as_syntax returned none'
		return
	}
	rhs := parse_as_syntax(rhs_values) or {
		assert false, 'rhs parse_as_syntax returned none'
		return
	}
	assert lhs.dump() == rhs.dump()
}

fn test_single_universal() {
	compare_dump([delim_cv('*')], 'Universal\n')
}

fn test_single_ident() {
	compare_dump([ident_cv('thing')], 'Ident: thing\n')
}

fn test_single_type() {
	names := ['angle', 'color', 'custom-ident', 'image', 'integer', 'length', 'length-percentage',
		'number', 'percentage', 'resolution', 'string', 'time', 'url', 'transform-function']
	for name in names {
		compare_dump(type_tokens(name), 'Type: ${name}\n')
	}
}

fn test_multiple_keywords() {
	values := [ident_cv('well'), delim_cv('|'), ident_cv('hello'), delim_cv('|'), ident_cv('friends')]
	compare_dump(values, 'Alternatives:\n  Ident: well\n  Ident: hello\n  Ident: friends\n')
}

fn test_repeated_type() {
	mut values := type_tokens('number')
	values << delim_cv('+')
	compare_dump(values, 'Multiplier:\n  Type: number\n')
}

fn test_repeated_with_commas() {
	mut values := type_tokens('number')
	values << delim_cv('#')
	compare_dump(values, 'CommaSeparatedMultiplier:\n  Type: number\n')
}

fn test_complex() {
	mut values := [ident_cv('well'), delim_cv('|')]
	values << type_tokens('number')
	values << delim_cv('+')
	values << delim_cv('|')
	values << type_tokens('string')
	values << delim_cv('#')
	compare_dump(values, 'Alternatives:\n  Ident: well\n  Multiplier:\n    Type: number\n  CommaSeparatedMultiplier:\n    Type: string\n')
}

fn test_syntax_string() {
	// A single string token's contents are parsed as if it was unquoted.
	expect_dumps_equal(type_tokens('number'), [string_cv('<number>')])

	mut values := [ident_cv('well'), delim_cv('|')]
	values << type_tokens('number')
	values << delim_cv('+')
	values << delim_cv('|')
	values << type_tokens('string')
	values << delim_cv('#')
	expect_dumps_equal(values, [string_cv('well | <number>+ | <string>#')])
}

fn test_invalid() {
	// Empty / whitespace / EOF / invalid.
	assert parse_as_syntax([]ComponentValue{}) == none
	assert parse_as_syntax([whitespace_cv()]) == none
	assert parse_as_syntax([ComponentValue.from_token(Token.create(.end_of_file, ''))]) == none
	assert parse_as_syntax([ComponentValue.from_token(Token.create(.invalid, ''))]) == none

	// Incomplete.
	assert parse_as_syntax([delim_cv('<'), ident_cv('number')]) == none
	assert parse_as_syntax([ident_cv('thing'), delim_cv('|')]) == none

	// '*' is only allowed on its own.
	assert parse_as_syntax([delim_cv('*'), delim_cv('|'), delim_cv('*')]) == none

	// <transform-list> cannot have multipliers.
	mut tl_plus := type_tokens('transform-list')
	tl_plus << delim_cv('+')
	assert parse_as_syntax(tl_plus) == none
	mut tl_hash := type_tokens('transform-list')
	tl_hash << delim_cv('#')
	assert parse_as_syntax(tl_hash) == none

	// For <syntax>, only predefined types are allowed.
	assert parse_as_syntax(type_tokens('woozle')) == none

	// <syntax> doesn't allow multiple types/keywords without a combinator.
	mut two_types := type_tokens('number')
	two_types << whitespace_cv()
	two_types << type_tokens('integer')
	assert parse_as_syntax(two_types) == none
	assert parse_as_syntax([ident_cv('thingy'), whitespace_cv(), ident_cv('whatsit')]) == none

	// Whitespace isn't allowed between a type and its multiplier.
	mut ws_plus := type_tokens('number')
	ws_plus << whitespace_cv()
	ws_plus << delim_cv('+')
	assert parse_as_syntax(ws_plus) == none
	mut ws_hash := type_tokens('number')
	ws_hash << whitespace_cv()
	ws_hash << delim_cv('#')
	assert parse_as_syntax(ws_hash) == none
}
