module libjs

fn test_lexer_keyword_lookup_preserves_keyword_and_identifier_tokens() {
	source := utf16(r'const c\u006fnst cůnst c\u016fnst constable true false null instanceof')
	mut lexer := Lexer.new(source, 1, 0)
	assert lexer.next().token_type == .const_kw
	escaped_keyword := lexer.next()
	assert escaped_keyword.token_type == .escaped_keyword
	assert (escaped_keyword.identifier_value or { panic('Missing decoded keyword') }).data == utf16('const')
	assert lexer.next().token_type == .identifier
	escaped_identifier := lexer.next()
	assert escaped_identifier.token_type == .identifier
	assert (escaped_identifier.identifier_value or { panic('Missing decoded identifier') }).data == utf16('cůnst')
	assert lexer.next().token_type == .identifier
	assert lexer.next().token_type == .bool_literal
	assert lexer.next().token_type == .bool_literal
	assert lexer.next().token_type == .null_literal
	assert lexer.next().token_type == .instanceof_kw
	assert lexer.next().token_type == .eof
}
