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

fn test_forward_references_and_child_references_share_the_declared_local() {
	parsed := parse_source('function f() { name; let name = 1; { name; name; } { name; name; } return name; }',
		.script)
	ast_text := parsed.dump_ast()!
	assert ast_text.count('Identifier "name" [variable:0] (let)') == 7, ast_text
}

fn test_child_references_keep_capture_and_local_slots_separate_between_functions() {
	parsed := parse_source('function first() { let name = 1; return () => name; }
		function second() { let name = 2; { return name; } }', .script)
	ast_text := parsed.dump_ast()!
	assert ast_text.count('Identifier "name" [variable:0] (let)') == 2, ast_text
}
