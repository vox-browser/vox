module libjs

fn test_function_scope_metadata_keeps_unicode_names_in_utf16() {
	parsed := parse_source('function outer() { var α = 1; var 𐐀 = 2; return () => α + 𐐀; }',
		.script)
	assert !parsed.has_errors(), '${parsed.diagnostics}'
	program := parsed.program.kind.program_data or { panic('missing program') }
	outer := parsed.function_table.get(program.scope.children[0].kind.function_id)
	scope := outer.body.kind.scope or { panic('missing scope') }
	metadata := scope.function_scope_data or { panic('missing metadata') }
	assert metadata.var_names.any(it.data == utf16('α'))
	assert metadata.var_names.any(it.data == utf16('𐐀'))
	assert metadata.vars_to_initialize.any(it.name.data == utf16('α'))
	assert metadata.vars_to_initialize.any(it.name.data == utf16('𐐀'))
}

fn test_formal_parameter_metadata_preserves_indices_and_escaped_name_identity() {
	parsed := parse_source(r'function f(α, {β}, [γ], \u{10400}, ...rest) {
		return α + β + γ + 𐐀 + rest.length;
	}', .script)
	ast := parsed.dump_ast()!
	assert ast.contains('Identifier "α" [argument:0]'), ast
	assert ast.contains('Identifier "𐐀" [argument:3]'), ast
	assert ast.contains('Identifier "rest" [argument:4]'), ast
	assert ast.contains('Identifier "β" [variable:0]'), ast
	assert ast.contains('Identifier "γ" [variable:1]'), ast
	for source in [r'function f(𐐀, \u{10400}) { "use strict"; }', r'(𐐀, \u{10400}) => 𐐀'] {
		duplicate := parse_source(source, .script)
		assert duplicate.diagnostics.any(it.message.contains("Duplicate parameter '𐐀'"))
	}
}

fn test_variable_metadata_keeps_escaped_names_and_utf16_sort_order() {
	parsed := parse_source(r'function outer() {
		var 𐐀 = 1;
		{ var \u{10400}; var α = 2; }
		function z() { return α; }
		return z() + 𐐀;
	}', .script)
	assert !parsed.has_errors(), '${parsed.diagnostics}'
	program := parsed.program.kind.program_data or { panic('missing program') }
	outer := parsed.function_table.get(program.scope.children[0].kind.function_id)
	scope := outer.body.kind.scope or { panic('missing scope') }
	metadata := scope.function_scope_data or { panic('missing metadata') }
	assert metadata.var_names.map(it.str()) == ['z', 'α', '𐐀']
	assert metadata.vars_to_initialize.map(it.name.str()) == ['z', 'α', '𐐀']
	assert metadata.vars_to_initialize[0].is_function_name

	conflict := parse_source(r'function outer() { let 𐐀 = 1; { var \u{10400}; } }', .script)
	assert conflict.diagnostics.any(it.message.contains("Identifier '𐐀' already declared"))
}
