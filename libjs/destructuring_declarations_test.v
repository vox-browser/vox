module libjs

fn test_destructured_bound_names_and_uses_retain_declaration_kinds() {
	for keyword in ['var', 'let', 'const'] {
		parsed := parse_source('function f() { ${keyword} {outer: [zebra, {inner: alpha}], ...rest} = value; return zebra + alpha + rest; }',
			.script)
		ast_text := parsed.dump_ast()!
		for name in ['zebra', 'alpha', 'rest'] {
			lines := ast_text.split_into_lines().filter(it.contains('Identifier "${name}"'))
			assert lines.len == 2, ast_text
			assert lines.all(it.contains('(${keyword})')), ast_text
		}
		assert !ast_text.split_into_lines().any(it.contains('Identifier "outer"')
			&& it.contains('(${keyword})')), ast_text
		assert !ast_text.split_into_lines().any(it.contains('Identifier "inner"')
			&& it.contains('(${keyword})')), ast_text
	}
}

fn test_destructured_loop_bindings_and_body_uses_keep_lexical_metadata() {
	parsed := parse_source('function f(items) { for (const [zebra, alpha] of items) { zebra; alpha; } }',
		.script)
	ast_text := parsed.dump_ast()!
	assert ast_text.count('Identifier "zebra" [variable:0] (const)') == 2, ast_text
	assert ast_text.count('Identifier "alpha" [variable:1] (const)') == 2, ast_text
}

fn test_assignment_and_parameter_patterns_do_not_become_declarations() {
	parsed := parse_source('function f({zebra}) { ({zebra} = value); return zebra; }', .script)
	ast_text := parsed.dump_ast()!
	assert !ast_text.contains('(var)'), ast_text
	assert !ast_text.contains('(let)'), ast_text
	assert !ast_text.contains('(const)'), ast_text
}
