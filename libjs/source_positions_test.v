module libjs

fn test_member_property_and_object_key_positions_use_their_own_tokens() {
	parsed := parse_source('obj.foo;\n({bar: 1});\nclass C { method() {} }', .script)
	ast_text := parsed.dump_ast()!
	assert ast_text.contains('Identifier "foo" @1:5'), ast_text
	assert ast_text.contains('StringLiteral "bar" @2:3'), ast_text
	assert ast_text.contains('StringLiteral "method" @3:11'), ast_text
}

fn test_binding_pattern_names_and_aliases_keep_individual_positions() {
	parsed := parse_source('let {first: a, second: b} = obj;\nlet [x, y] = arr;', .script)
	ast_text := parsed.dump_ast()!
	assert ast_text.contains('Identifier "first" [global] @1:6'), ast_text
	assert ast_text.contains('Identifier "a" [global]'), ast_text
	assert ast_text.contains('@1:13'), ast_text
	assert ast_text.contains('Identifier "second" [global] @1:16'), ast_text
	assert ast_text.contains('Identifier "b" [global]'), ast_text
	assert ast_text.contains('@1:24'), ast_text
	assert ast_text.split_into_lines().any(it.contains('Identifier "x"') && it.ends_with('@2:6')), ast_text
	assert ast_text.split_into_lines().any(it.contains('Identifier "y"') && it.ends_with('@2:9')), ast_text
}

fn test_lexer_restarts_at_the_authored_code_unit_column() {
	mut lexer := Lexer.new_at_offset(utf16('   a'), 3, 7, 4)
	token := lexer.next()
	assert token.line_number == 7
	assert token.line_column == 4
	assert token.value_start == 3
}

fn test_ascii_punctuators_preserve_token_and_eof_positions() {
	for spelling, kind in {
		';': TokenType.semicolon
		'=': TokenType.equals
		'=>': TokenType.arrow
		'===': TokenType.equals_equals_equals
		'>>>=': TokenType.unsigned_shift_right_equals
	} {
		mut lexer := Lexer.new(utf16(spelling), 1, 0)
		token := lexer.next()
		assert token.token_type == kind
		assert token.line_column == 1
		assert token.value_len == u32(spelling.len)
		eof := lexer.next()
		assert eof.token_type == .eof
		assert eof.value_start == u32(spelling.len)
		assert eof.line_column == u32(spelling.len + 1)
	}
}

fn test_ascii_punctuator_keeps_crlf_trivia_and_the_following_unicode_unit() {
	mut lexer := Lexer.new(utf16(';\r\n>>>=λ'), 1, 0)
	assert lexer.next().token_type == .semicolon
	operator := lexer.next()
	assert operator.token_type == .unsigned_shift_right_equals
	assert operator.trivia_has_line_terminator
	assert operator.line_number == 2
	assert operator.line_column == 1
	assert operator.value_start == 3
	identifier := lexer.next()
	assert identifier.token_type == .identifier
	assert identifier.line_number == 2
	assert identifier.line_column == 5
	assert identifier.value_start == 7
}

fn test_string_spans_keep_unicode_lines_and_lookahead_positions() {
	mut lexer := Lexer.new(utf16('"ASCII 🙂λ\u2028body" next'), 1, 0)
	preview := lexer.peek()
	assert preview.token_type == .string_literal
	assert preview.value_len == 16
	assert lexer.next().value_len == preview.value_len
	identifier := lexer.next()
	assert identifier.token_type == .identifier
	assert identifier.line_number == 2
	assert identifier.line_column == 7
	assert identifier.value_start == 17
}

fn test_string_spans_stop_at_escapes_and_eof() {
	mut escaped := Lexer.new(utf16(r'"ordinary \"quoted\" text"'), 1, 0)
	token := escaped.next()
	assert token.token_type == .string_literal
	assert token.value_len == 26
	mut unfinished := Lexer.new(utf16('"ordinary text through EOF'), 1, 0)
	invalid := unfinished.next()
	assert invalid.token_type == .unterminated_string_literal
	assert invalid.value_len == 26
	assert unfinished.next().token_type == .eof
}
