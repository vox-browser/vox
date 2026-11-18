module libjs

fn test_lexer_ascii_identifier_runs_preserve_unicode_and_source_positions() {
	first_source := r'alpha0_$𐐀more\u0061bc'
	private_source := '#private3tail'
	source := utf16(first_source + '\r\n' + private_source + ';éclair_ends42')
	mut lexer := Lexer.new(source, 1, 0)
	first := lexer.next()
	assert first.token_type == .identifier
	assert first.value_len == u32(utf16(first_source).len)
	assert (first.identifier_value or { panic('Missing decoded identifier') }).str() == 'alpha0_$𐐀moreabc'

	private_token := lexer.next()
	assert private_token.token_type == .private_identifier
	assert private_token.offset == first.value_len + 2
	assert private_token.line_number == 2
	assert private_token.line_column == 1
	assert private_token.trivia_has_line_terminator

	separator := lexer.next()
	assert separator.token_type == .semicolon
	assert separator.line_column == u32(private_source.len + 1)
	last := lexer.next()
	assert last.token_type == .identifier
	assert last.line_column == separator.line_column + 1
	assert last.value_len == u32(utf16('éclair_ends42').len)
	end := lexer.next()
	assert end.token_type == .eof
	assert end.offset == u32(source.len)
	assert end.line_column == last.line_column + last.value_len
}
