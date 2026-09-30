module libjs

fn test_static_block_nested_functions_allow_await_binding_names() {
	for source in [
		'class C { static { (function await(await) { return await; }); } }',
		'class C { static { (function* await(await) { yield await; }); } }',
		'class C { static { function f() { await => 0; } } }',
	] {
		parsed := parse_source(source, .script)
		assert !parsed.has_errors(), '${source}: ${parsed.diagnostics}'
	}
	for source in ['class C { static { await => 0; } }',
		'class C { static { async function await() {} } }'] {
		assert parse_source(source, .script).has_errors(), source
	}
}

fn test_class_field_initializers_reset_await_expression_grammar() {
	parsed := parse_source('async function f() { return class { field = await; other = 1; }; }',
		.script)
	ast_text := parsed.dump_ast()!
	assert ast_text.contains('Identifier "await"'), ast_text
	assert !ast_text.contains('AwaitExpression'), ast_text
	assert parse_source('async () => class { field = await 1 };', .script).has_errors()
	assert parse_source('async () => class { [await] = 1 };', .script).has_errors()
}

fn test_class_computed_keys_restore_enclosing_await_context_after_initializers() {
	parsed := parse_source('async function f() { return class { first = await; [await key] = 1; }; }',
		.script)
	ast_text := parsed.dump_ast()!
	assert ast_text.contains('Identifier "await"'), ast_text
	assert ast_text.contains('AwaitExpression'), ast_text
}
