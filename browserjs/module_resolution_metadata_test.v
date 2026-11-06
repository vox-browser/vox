module browserjs

import dom
import html

fn test_module_resolution_records_original_normalization_and_descendant_options() {
	base := 'https://resolution.test/app/page.js'
	mut document := html.create_navigation_document(dom.URL{value: base}, dom.URL{value: base}.origin(), none)!
	defer { document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut scope := settings.universal_global_scope()
	import_map := html.parse_import_map_string('{"imports":{"dep":"data:text/javascript,42","./source.js":"data:text/javascript,43","data:text/javascript,44":"./target.js"},"integrity":{"./target.js":"sha256-target"}}', document.url)!
	scope.set_import_map(&import_map)
	mut host := ModuleHost.create(settings, module_test_transport({}, &ModuleTestRequests{}))
	host.sources['parent'] = BrowserModuleSource{options: html.ScriptFetchOptions{
		cryptographic_nonce: 'nonce', integrity_metadata: 'parent-integrity', credentials_mode: .include,
		referrer_policy: 'no-referrer', fetch_priority: .high
	}}
	inputs := ['dep', './source.js', 'data:text/javascript,44']
	targets := ['data:text/javascript,42', 'data:text/javascript,43', 'https://resolution.test/app/target.js']
	normalized := ['dep', 'https://resolution.test/app/source.js', 'data:text/javascript,44']
	for index, input in inputs {
		key := host.resolve(input, base, 'parent')!
		assert key == targets[index]
		records := settings.resolved_module_set()
		assert records.len == index + 1
		assert (records[index].serialized_base_url or { panic('missing base') }) == base
		assert records[index].specifier == normalized[index]
		assert records[index].specifier_is_null_or_url_like_that_is_special == (index != 2)
		source := host.sources[key] or { panic('missing source') }
		assert source.base == key && (source.referrer.url or { panic('missing referrer') }).serialize() == base
		assert source.options.cryptographic_nonce == 'nonce' && source.options.credentials_mode == .include
		assert source.options.referrer_policy == 'no-referrer' && source.options.fetch_priority == .auto
		assert source.options.integrity_metadata == if index == 2 { 'sha256-target' } else { '' }
	}
}

fn test_module_resolution_bookkeeping_filters_late_import_maps_using_input_url() {
	base := 'https://resolution.test/app/page.js'
	mut document := html.create_navigation_document(dom.URL{value: base}, dom.URL{value: base}.origin(), none)!
	defer { document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut scope := settings.universal_global_scope()
	import_map := html.parse_import_map_string('{"imports":{"./source.js":"data:text/javascript,42"}}', document.url)!
	scope.set_import_map(&import_map)
	mut host := ModuleHost.create(settings, module_test_transport({}, &ModuleTestRequests{}))
	assert host.resolve('./source.js', base, '')! == 'data:text/javascript,42'
	late := html.parse_import_map_string('{"scopes":{"/app/":{"./source.js":"/changed.js","./fresh.js":"/fresh.js"}}}', document.url)!
	mut installed_map := unsafe { &html.ImportMap(scope.import_map()) }
	html.merge_existing_and_new_import_maps(mut installed_map, &late, settings.resolved_module_set(), fn (_ string) {})
	assert host.resolve('./source.js', base, '')! == 'data:text/javascript,42'
	assert host.resolve('./fresh.js', base, '')! == 'https://resolution.test/fresh.js'
	assert host.sources.len == 2
}

fn test_failed_module_resolution_publishes_no_source_or_resolved_record() {
	base := 'https://resolution.test/page.js'
	mut document := html.create_navigation_document(dom.URL{value: base}, dom.URL{value: base}.origin(), none)!
	defer { document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut scope := settings.universal_global_scope()
	import_map := html.parse_import_map_string('{"imports":{"blocked":null,"pkg/":"https://cdn.test/pkg/"}}', document.url)!
	scope.set_import_map(&import_map)
	mut host := ModuleHost.create(settings, module_test_transport({}, &ModuleTestRequests{}))
	for input in ['missing', 'blocked', 'pkg/../escape.js'] {
		if _ := host.resolve(input, base, '') { assert false, input }
		assert settings.resolved_module_set().len == 0 && host.sources.len == 0
	}
	assert host.resolve('./valid.js', base, '')! == 'https://resolution.test/valid.js'
	assert settings.resolved_module_set().len == 1 && host.sources.len == 1
}
