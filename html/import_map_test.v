module html

import dom

fn test_parse_import_map_normalizes_and_sorts() {
	base := dom.URL{value: 'https://example.test/app/index.html'}
	import_map := parse_import_map_string('{"imports":{"z":"./z.js","./a":"./a.js","pkg/":"https://cdn.test/pkg/"},"scopes":{"/app/":{"dep":"./dep.js"}},"integrity":{"./a.js":"sha256-a"}}',
		base) or { panic('${err}') }
	assert import_map.imports.entries.len == 3
	assert import_map.imports.entries[0].specifier == 'z'
	assert import_map.imports.entries[1].specifier == 'pkg/'
	assert import_map.imports.entries[2].specifier == 'https://example.test/app/a'
	assert import_map.scopes[0].prefix == 'https://example.test/app/'
	assert import_map.integrity[0].url.serialize() == 'https://example.test/app/a.js'
}

fn test_import_map_rejects_non_objects_and_normalizes_null_entries() {
	base := dom.URL{value: 'https://example.test/'}
	if _ := parse_import_map_string('[]', base) {
		assert false
	}
	import_map := parse_import_map_string('{"imports":{"blocked":null,"bad":42,"empty/":"./file"}}',
		base) or { panic('${err}') }
	assert import_map.imports.entries.len == 3
	for entry in import_map.imports.entries {
		assert entry.url == none
	}
	if _ := resolve_module_specifier(&import_map, base, 'blocked') {
		assert false
	}
}

fn test_import_map_exact_prefix_scope_and_backtracking_resolution() {
	base := dom.URL{value: 'https://example.test/app/page.js'}
	import_map := parse_import_map_string('{"imports":{"pkg/":"https://cdn.test/pkg/","exact":"https://cdn.test/exact.js"},"scopes":{"https://example.test/app/":{"exact":"./scoped.js"}}}',
		base) or { panic('${err}') }
	exact := resolve_module_specifier(&import_map, base, 'exact') or { panic('${err}') }
	assert exact.serialize() ==
		'https://example.test/app/scoped.js'
	prefixed := resolve_module_specifier(&import_map, base, 'pkg/util.js') or { panic('${err}') }
	assert prefixed.serialize() ==
		'https://cdn.test/pkg/util.js'
	local := resolve_module_specifier(&import_map, base, './local.js') or { panic('${err}') }
	assert local.serialize() ==
		'https://example.test/app/local.js'

	mut prefix_map := ModuleSpecifierMap{}
	prefix_map.set('pkg/', dom.URL{value: 'https://cdn.test/pkg/'})
	if _ := resolve_imports_match('pkg/../escape.js', none, &prefix_map) {
		assert false
	}
}

fn test_merge_import_maps_preserves_old_and_filters_resolved_rules() {
	base := dom.URL{value: 'https://example.test/'}
	mut old_map := parse_import_map_string('{"imports":{"old":"./old.js","same":"./first.js"},"integrity":{"./old.js":"old-integrity"}}',
		base) or { panic('${err}') }
	new_map := parse_import_map_string('{"imports":{"new":"./new.js","same":"./second.js","old/sub":"./sub.js"},"integrity":{"./old.js":"replacement","./new.js":"new-integrity"}}',
		base) or { panic('${err}') }
	records := [ResolvedModuleRecord{
		specifier: 'old'
		specifier_is_null_or_url_like_that_is_special: true
	}]
	merge_existing_and_new_import_maps(mut old_map, &new_map, records, ignore_import_map_warning)
	assert old_map.imports.contains('old')
	assert old_map.imports.contains('same')
	assert old_map.imports.contains('new')
	assert !old_map.imports.contains('old/sub')
	assert old_map.integrity.len == 2
}
