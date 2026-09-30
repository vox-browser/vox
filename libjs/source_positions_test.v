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
