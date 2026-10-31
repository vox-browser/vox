module html

import dom

fn test_parser_import_maps_register_in_the_owning_window_and_merge_in_tree_order() {
	url := dom.URL{value: 'https://maps.test/owner'}
	mut document := create_navigation_document(url, url.origin(), none)!
	defer { document.finalize() }
	document.set_ready_to_run_scripts()
	parse_html_from_a_string(document, '<!doctype html><script type="importmap">{"imports":{"first":"/one.js"}}</script><script type="importmap">{"imports":{"first":"/changed.js","second":"/two.js"}}</script>')
	settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	actual := settings.universal_global_scope().import_map()
	assert resolve_module_specifier(actual, url, 'first')!.serialize() == 'https://maps.test/one.js'
	assert resolve_module_specifier(actual, url, 'second')!.serialize() == 'https://maps.test/two.js'
	other := create_navigation_document(url, url.origin(), none)!
	defer { other.finalize() }
	other_settings := unsafe { &EnvironmentSettingsObject(other.relevant_settings_object()) }
	assert other_settings.universal_global_scope().import_map().imports().entries.len == 0
}
