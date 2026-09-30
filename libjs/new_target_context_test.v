module libjs

fn test_global_arrows_do_not_create_a_new_target_binding() {
	for source in ['new.target;', '() => new.target;', '() => { return new.target; };',
		'async () => new.target;', '() => () => new.target;', 'function f() {} () => new.target;',
		'({ method() {} }); () => new.target;'] {
		parsed := parse_source(source, .script)
		assert parsed.has_errors(), source
		assert parsed.diagnostics.any(it.message.contains('new.target')), '${parsed.diagnostics}'
	}
}

fn test_arrows_inherit_new_target_from_functions_methods_and_static_blocks() {
	for source in ['function f() { return () => new.target; }', 'function f(x = () => new.target) {}',
		'({ method() { return () => new.target; } });',
		'class C { method() { return () => new.target; } }',
		'class C { static { (() => new.target)(); } }'] {
		parsed := parse_source(source, .script)
		assert !parsed.has_errors(), '${source}: ${parsed.diagnostics}'
	}
}
