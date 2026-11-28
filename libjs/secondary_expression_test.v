module libjs

fn test_secondary_expression_boundaries_preserve_prefix_and_for_in_parsing() {
	parsed := parse_source('a\n++b; new Foo().bar; for (let item in items) item;', .script)
	assert !parsed.has_errors(), '${parsed.diagnostics}'
	statements := parsed.program.kind.program_data?.scope.children
	assert statements.len == 4
	assert statements[0].kind.expression?.kind.tag == .identifier_expr
	update := statements[1].kind.expression?.kind
	assert update.tag == .update
	assert update.prefixed
	assert statements[3].kind.tag == .block
	loop := statements[3].kind.scope?.children[0].kind
	assert loop.tag == .for_in_of
}
