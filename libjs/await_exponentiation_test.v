module libjs

fn test_await_uses_unary_expression_exponentiation_early_errors() {
	for source in ['async function f() { await 5 ** 2; }', 'async () => await value ** 2;',
		'await 5 ** 2;'] {
		type_ := if source.starts_with('await') { SourceType.module } else { SourceType.script }
		parsed := parse_source(source, type_)
		assert parsed.has_errors(), source
		assert parsed.diagnostics.any(it.message.contains('left-hand side')), '${parsed.diagnostics}'
	}
	for source in ['async function f() { (await 5) ** 2; }', 'async function f() { await (5 ** 2); }',
		'async function f() { 5 ** await 2; }', 'async function f() { await 1 + 2; }',
		'await => await ** 2;'] {
		parsed := parse_source(source, .script)
		assert !parsed.has_errors(), '${source}: ${parsed.diagnostics}'
	}
}
