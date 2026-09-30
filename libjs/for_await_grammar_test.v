module libjs

fn test_for_await_accepts_only_of_loop_heads() {
	for head in ['value of []', 'const value of []', 'async of []'] {
		for prefix in ['async function f()', 'async function* f()'] {
			parsed := parse_source('${prefix} { for await (${head}) ; }', .script)
			assert !parsed.has_errors(), '${head}: ${parsed.diagnostics}'
		}
	}
	for head in [';;', 'value ;;', 'let value = 0; value < 1; value++', 'value in []'] {
		source := 'async function* f() { for await (${head}) ; }'
		assert parse_source(source, .script).has_errors(), source
	}
	assert parse_source('function f() { for await (value of []) ; }', .script).has_errors()
}

fn test_async_assignment_target_exclusion_applies_only_to_ordinary_for_of() {
	assert parse_source('for (async of []) ;', .script).has_errors()
	for source in ['for (\\u0061sync of []) ;', 'for (async.value of []) ;',
		'async function f() { for await (async of []) ; }', 'for (async in []) ;'] {
		parsed := parse_source(source, .script)
		assert !parsed.has_errors(), '${source}: ${parsed.diagnostics}'
	}
}
