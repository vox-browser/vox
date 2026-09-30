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
