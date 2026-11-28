module libjs

fn test_arrow_expression_bodies_preserve_for_head_no_in_context() {
	for arrow in ['x =>', '(x) =>', '() =>', 'async x =>', 'async (x) =>'] {
		invalid := 'for (${arrow} 0 in 1;;);'
		assert parse_source(invalid, .script).has_errors(), invalid
		for source in ['for (${arrow} (0 in 1);;);', 'for ((${arrow} 0 in 1);;);',
			'for (${arrow} { return 0 in 1; };;);'] {
			parsed := parse_source(source, .script)
			assert !parsed.has_errors(), '${source}: ${parsed.diagnostics}'
		}
	}
}

fn test_arrows_nested_in_parameter_defaults_reset_outer_no_in_context() {
	for source in ['for ((x = y => 0 in obj) => x;;);', 'for ((x = async y => 0 in obj) => x;;);'] {
		parsed := parse_source(source, .script)
		assert !parsed.has_errors(), '${source}: ${parsed.diagnostics}'
	}
}

fn test_parenthesized_arrow_lookahead_preserves_grouped_expressions_and_calls() {
	for source in ['(value.property);', '(value + 1);', '(function () {});', '(42);',
		'async(value.property);', 'async();', 'async(value, other);'] {
		assert !parse_source(source, .script).has_errors(), source
	}
	for source in ['(value.property) => value', '(42) => 42', '()/*\n*/=> 1',
		'async()/*\n*/=> 1'] {
		assert parse_source(source, .script).has_errors(), source
	}
}

fn test_parenthesized_arrow_lookahead_accepts_formal_parameter_prefixes() {
	for source in ['() /* comment */ => 1', '(x) => x', '(x,) => x', '(x = 1) => x',
		'({x}) => x', '([x]) => x', '(...xs) => xs', '(yield) => yield', '(await) => await',
		r'(\u0061sync) => async', 'async () => 1', 'async (x) => x',
		'async ({x} = {x: 1}) => x'] {
		assert !parse_source(source, .script).has_errors(), source
	}
}
