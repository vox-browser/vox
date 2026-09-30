module libjs

fn test_deep_input_reports_a_syntax_error_and_unwinds_parser_depth() {
	depth := int(max_parser_recursion_depth) + 10
	for source in [
		'('.repeat(depth) + '0' + ')'.repeat(depth) + ';',
		'{'.repeat(depth) + ';' + '}'.repeat(depth),
		'let ' + '['.repeat(depth) + 'a' + ']'.repeat(depth) + ' = [];',
		'('.repeat(5000) + '0' + ')'.repeat(5000) + ';',
	] {
		mut parser := Parser.new(utf16(source), .script)
		parser.parse_program(false)
		assert parser.recursion_limit_reached
		assert parser.done()
		assert parser.recursion_depth == 0
		assert parser.errors.any(it.message == 'Maximum parser recursion depth exceeded')
	}
}

fn test_ordinary_nesting_and_speculative_arrows_release_the_depth_counter() {
	for source in ['('.repeat(16) + '1' + ')'.repeat(16) + ';', 'const f = (a, b) => ({a, b});',
		'const value = (a + b);'] {
		mut parser := Parser.new(utf16(source), .script)
		parser.parse_program(false)
		assert !parser.has_errors(), '${parser.errors}'
		assert parser.recursion_depth == 0
		assert !parser.recursion_limit_reached
	}
}

fn test_public_frontend_distinguishes_stack_budget_from_ordinary_syntax_errors() {
	assert parse_source('('.repeat(40) + '1' + ')'.repeat(40), .script).reached_recursion_limit
	assert !parse_source('let duplicate; let duplicate;', .script).reached_recursion_limit
}
