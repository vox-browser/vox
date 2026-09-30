module libjs

fn test_locals_follow_first_reference_order_instead_of_alphabetical_order() {
	parsed := parse_source('function f() { let zebra = 1; let alpha = 2; return zebra + alpha; }',
		.script)
	ast_text := parsed.dump_ast()!
	assert ast_text.contains('Identifier "zebra" [variable:0] (let)'), ast_text
	assert ast_text.contains('Identifier "alpha" [variable:1] (let)'), ast_text
}

fn test_catch_bindings_and_references_keep_source_order() {
	parsed := parse_source('function f() { try {} catch ({msg, code}) { return msg + code; } }',
		.script)
	ast_text := parsed.dump_ast()!
	assert ast_text.count('Identifier "msg" [variable:0]') == 2, ast_text
	assert ast_text.count('Identifier "code" [variable:1]') == 2, ast_text
}

fn test_captured_names_do_not_reorder_remaining_locals() {
	parsed := parse_source('function outer() { let captured = 1; let zebra = 2; function alpha() { return captured; } return alpha() + zebra; }',
		.script)
	ast_text := parsed.dump_ast()!
	assert ast_text.contains('Identifier "zebra" [variable:0] (let)'), ast_text
	assert ast_text.contains('Identifier "alpha" [variable:1]'), ast_text
	assert !ast_text.contains('Identifier "captured" [variable:'), ast_text
}
