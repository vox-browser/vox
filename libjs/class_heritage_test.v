module libjs

fn test_class_heritage_rejects_unparenthesized_arrow_functions() {
	for source in ['class A extends () => {} {}', 'class A extends async () => {} {}',
		'const A = class extends () => {} {};', 'const A = class extends async () => {} {};',
		'class A extends x => x {}'] {
		parsed := parse_source(source, .script)
		assert parsed.has_errors(), source
		assert parsed.diagnostics.any(it.message.contains('class heritage')), '${parsed.diagnostics}'
	}
}

fn test_class_heritage_accepts_grouped_arrows_and_arrows_inside_calls() {
	for source in ['class A extends (() => {}) {}', 'class A extends (async () => {}) {}',
		'class A extends mixin(() => 1) {}', 'const A = class extends mixin(async () => 1) {};'] {
		parsed := parse_source(source, .script)
		assert !parsed.has_errors(), '${source}: ${parsed.diagnostics}'
	}
}
