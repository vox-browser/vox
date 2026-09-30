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
