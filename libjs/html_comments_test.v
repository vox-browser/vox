module libjs

fn test_html_close_comments_after_whitespace_crossing_a_line() {
	for separator in [' \n', '\t\r\n  ', ' \r\t', '\x0b\n\x0c'] {
		source := '1;${separator}--> ignored text\n2;'
		mut lexer := Lexer.new(utf16(source), 1, 0)
		assert lexer.next().token_type == .numeric_literal
		assert lexer.next().token_type == .semicolon
		second := lexer.next()
		assert second.token_type == .numeric_literal, source
		assert second.trivia_has_line_terminator
		mut parser := Parser.new(utf16(source), .script)
		parser.parse_program(false)
		assert !parser.has_errors(), '${source}: ${parser.errors}'
	}
}

fn test_html_close_comments_remain_disabled_for_modules_and_same_line_tokens() {
	mut module_lexer := Lexer.new(utf16('1; \n--> comment'), 1, 0)
	module_lexer.disallow_html_comments()
	module_lexer.next()
	module_lexer.next()
	assert module_lexer.next().token_type == .minus_minus
	mut same_line := Lexer.new(utf16('1; --> comment'), 1, 0)
	same_line.next()
	same_line.next()
	assert same_line.next().token_type == .minus_minus
}
