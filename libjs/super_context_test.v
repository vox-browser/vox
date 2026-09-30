module libjs

fn test_regular_nested_functions_do_not_inherit_super_permissions() {
	for source in [
		'class C extends B { constructor() { function f() { super(); } } }',
		'class C extends B { method() { return function() { return super.value; }; } }',
		'({ method() { function f() { super.value; } } });',
	] {
		parsed := parse_source(source, .script)
		assert parsed.has_errors(), source
		assert parsed.diagnostics.any(it.message.contains('super')), '${parsed.diagnostics}'
	}
}

fn test_arrows_inherit_super_permissions_and_nested_functions_restore_them() {
	for source in ['class C extends B { constructor() { (() => super())(); } }',
		'class C extends B { method() { return () => super.value; } }',
		'class C extends B { constructor() { function f() {} super(); } method() { function f() {} super.value; } }'] {
		parsed := parse_source(source, .script)
		assert !parsed.has_errors(), '${source}: ${parsed.diagnostics}'
	}
}
