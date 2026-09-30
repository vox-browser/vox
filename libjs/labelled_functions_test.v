module libjs

fn test_sloppy_function_bodies_allow_labelled_normal_functions() {
	for body in ['label: function f() {};', 'var f; label: function f() {};',
		'label: function f() {}; var f;'] {
		parsed := parse_source('function outer() { ${body} }', .script)
		assert !parsed.has_errors(), '${body}: ${parsed.diagnostics}'
	}
	for body in ["'use strict'; label: function f() {};", 'label: function* f() {};',
		'label: async function f() {};'] {
		assert parse_source('function outer() { ${body} }', .script).has_errors(), body
	}
}

fn test_labelled_functions_conflict_with_lexical_declarations_in_either_order() {
	for body in ['let f; label: function f() {};', 'label: function f() {}; let f;',
		'const f = 1; label: function f() {};'] {
		parsed := parse_source('function outer() { ${body} }', .script)
		assert parsed.has_errors(), body
		assert parsed.diagnostics.any(it.message.contains('already declared')), '${parsed.diagnostics}'
	}
}
