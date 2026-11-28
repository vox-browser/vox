module libjs

fn test_lexer_reuses_lookahead_without_advancing_the_current_token() {
	mut lexer := Lexer.new(utf16('let\r\nvalue = 1'), 1, 0)
	assert lexer.next().token_type == .let_kw
	lexer.save_state()
	lookahead := lexer.peek()
	assert lexer.has_lookahead
	assert lexer.peek().value_start == lookahead.value_start
	assert lexer.current_token_type == .let_kw
	assert lookahead.token_type == .identifier
	assert lookahead.line_number == 2
	assert lookahead.line_column == 1
	assert lookahead.trivia_has_line_terminator
	assert lexer.next().value_start == lookahead.value_start
	assert lexer.peek().token_type == .equals
	lexer.load_state()
	assert lexer.next().token_type == .identifier
	assert lexer.next().token_type == .equals
	assert lexer.next().token_type == .numeric_literal
	assert lexer.next().token_type == .eof
}

fn test_lookahead_retains_decoded_identifiers_and_invalid_token_messages() {
	mut lexer := Lexer.new(utf16(r'\u0065val 1e+'), 1, 0)
	identifier := lexer.peek()
	assert identifier.token_type == .identifier
	assert lexer.next().value_start == identifier.value_start
	invalid := lexer.peek()
	assert invalid.token_type == .invalid
	assert lexer.next().value_start == invalid.value_start
	assert lexer.next().token_type == .eof
	assert identifier.identifier_value != unsafe { nil }
	assert utf16_equals_ascii(identifier.identifier_value.data, 'eval')
	assert invalid.message != unsafe { nil }
	assert invalid.message.text == 'Invalid numeric literal'
}

fn test_lexer_peek_preserves_template_interpolation_state() {
	mut lexer := Lexer.new(utf16(r'`a${{}}b` + 1'), 1, 0)
	assert lexer.peek().token_type == .template_literal_start
	assert lexer.next().token_type == .template_literal_start
	for kind in [TokenType.template_literal_string, .template_literal_expr_start, .curly_open,
		.curly_close, .template_literal_expr_end, .template_literal_string, .template_literal_end,
		.plus, .numeric_literal, .eof] {
		assert lexer.peek().token_type == kind
		assert lexer.peek().token_type == kind
		assert lexer.next().token_type == kind
	}
}

fn test_lexer_lookahead_respects_regex_reinterpretation_and_comment_mode() {
	mut lexer := Lexer.new(utf16('value /[a]/gi + 1'), 1, 0)
	assert lexer.next().token_type == .identifier
	assert lexer.next().token_type == .slash
	assert lexer.peek().token_type == .bracket_open
	assert lexer.force_slash_as_regex().token_type == .regex_literal
	assert lexer.next().token_type == .regex_flags
	assert lexer.next().token_type == .plus

	mut comments := Lexer.new(utf16('<!-- ignored\nvalue'), 1, 0)
	assert comments.peek().token_type == .identifier
	comments.disallow_html_comments()
	assert comments.next().token_type == .less_than
}
