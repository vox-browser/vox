module libjs

fn test_literal_keys_do_not_mark_arguments_or_eval_as_references() {
	for body in ['return {arguments: 1, eval: 2};', 'let {arguments: x, eval: y} = value;',
		'return {arguments() {}, eval() {}};'] {
		parsed := parse_source('function f() { ${body} }', .script)
		ast_text := parsed.dump_ast()!
		assert !ast_text.contains('[might-need-arguments]'), ast_text
	}
}

fn test_computed_keys_track_references_including_nested_expressions() {
	for body in ['return {[arguments]: 1};', 'return {[eval]: 1};', 'return {[{[arguments]: 1}]: 2};',
		'let {[arguments]: x} = value;', 'class C { [arguments]() {} }'] {
		parsed := parse_source('function f() { ${body} }', .script)
		ast_text := parsed.dump_ast()!
		assert ast_text.contains('FunctionDeclaration "f" [might-need-arguments]'), ast_text
	}
}

fn test_computed_class_field_key_does_not_suppress_initializer_early_errors() {
	assert !parse_source('class C { field = {arguments: 1}; }', .script).has_errors()
	for source in ['class C { field = {[arguments]: 1}; }', 'class C { field = {[1]: arguments}; }'] {
		parsed := parse_source(source, .script)
		assert parsed.has_errors(), source
		assert parsed.diagnostics.any(it.message.contains('class field initializer')), '${parsed.diagnostics}'
	}
}
