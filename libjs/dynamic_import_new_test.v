module libjs

fn test_new_accepts_grouped_dynamic_import_callees() {
	assert parse_source("new import('a');", .script).has_errors()
	for source in ["new (import('a'));", "new ((import('a')))();",
		"new (import('a'), function() {});", "new (import('a')).constructor();"] {
		parsed := parse_source(source, .script)
		assert !parsed.has_errors(), '${source}: ${parsed.diagnostics}'
	}
}
