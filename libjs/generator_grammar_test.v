module libjs

fn test_yield_operands_preserve_no_in_context_in_for_heads() {
	for source in ["function* f() { for (yield '' in {}; ;); }",
		"function* f() { for (yield * '' in {}; ;); }"] {
		assert parse_source(source, .script).has_errors(), source
	}
	for source in ["function* f() { for (yield ('' in {}); ;); }",
		"function* f() { for (yield * ('' in {}); ;); }", "function* f() { yield '' in {}; }"] {
		parsed := parse_source(source, .script)
		assert !parsed.has_errors(), '${source}: ${parsed.diagnostics}'
	}
}

fn test_generator_expression_names_reject_yield_without_rejecting_sloppy_declarations() {
	for source in ['function f() { (function* yield() {}); }', 'var g = function* yield() {};'] {
		parsed := parse_source(source, .script)
		assert parsed.has_errors(), source
		assert parsed.diagnostics.any(it.message.contains('generator function expression name')), '${parsed.diagnostics}'
	}
	for source in ['function* yield() {}', 'function* outer() { (function yield() {}); }'] {
		parsed := parse_source(source, .script)
		assert !parsed.has_errors(), '${source}: ${parsed.diagnostics}'
	}
}
