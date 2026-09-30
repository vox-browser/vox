module libjs

fn labelled_outer_scope(parsed &ParsedSource) &ScopeData {
	program := parsed.program.kind.program_data or { panic('missing program') }
	outer := parsed.function_table.get(program.scope.children[0].kind.function_id)
	return outer.body.kind.scope or { panic('missing function body scope') }
}

fn test_labelled_function_initialization_keeps_source_order_and_last_duplicate() {
	parsed := parse_source('function outer() { first: function zebra() {} second: function alpha() {} function zebra() {} }',
		.script)
	assert !parsed.has_errors(), '${parsed.diagnostics}'
	scope := labelled_outer_scope(parsed)
	metadata := scope.function_scope_data or { panic('missing metadata') }
	assert metadata.functions_to_initialize.map(it.child_index) == [1, 2]
	assert metadata.vars_to_initialize.filter(it.is_function_name).len == 2
	assert metadata.var_names.any(it.str() == 'zebra')
	assert metadata.var_names.any(it.str() == 'alpha')
}

fn test_labelled_block_functions_receive_annex_b_hoisting_metadata() {
	parsed := parse_source('function outer() { { label: function f() {} } }', .script)
	assert !parsed.has_errors(), '${parsed.diagnostics}'
	scope := labelled_outer_scope(parsed)
	assert scope.annexb_function_names.any(it.str() == 'f')
	block := scope.children[0].kind.scope or { panic('missing block') }
	declaration := block.children[0].function_declaration_for_labelled_item() or {
		panic('missing labelled function')
	}
	assert declaration.kind.is_hoisted
	assert scope.children[0].function_declaration_for_labelled_item() == none
}
