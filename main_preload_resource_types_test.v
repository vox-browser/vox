module main

import dom
import html

fn preload_resource_type_test_document(markup string) &dom.Document {
	address := dom.dom_url_parse('https://preload-types.test/dir/page.html', dom.url_about_blank(), 'UTF-8') or { panic('bad fixture URL') }
	origin := html.determine_the_origin(address, html.SandboxingFlagSet{}, none)
	return html.parse_navigation_document(markup, address, origin, none) or { panic(err) }
}

fn test_preload_resource_types_resolve_base_and_keep_stylesheet_script_image_priority() {
	document := preload_resource_type_test_document('<!doctype html><base href="../assets/"><img src="./shared.svg#part"><script src="../assets/shared.svg#part"></script><link rel="alternate STYLESHEET" href="./shared.svg#part"><script src="https://cdn.preload-types.test/direct.js"></script><img src="image.png">')
	types := document_preload_resource_types(document, document.base_url().serialize())
	assert types['https://preload-types.test/assets/shared.svg#part'] == 'stylesheet'
	assert types['https://cdn.preload-types.test/direct.js'] == 'script'
	assert (types['https://preload-types.test/assets/image.png'] or { 'image' }) == 'image'
	assert types.len == 2
}

fn test_preload_resource_types_keep_existing_rel_token_and_script_type_semantics() {
	document := preload_resource_type_test_document('<!doctype html><link rel=" alternate  stylesheet " href="valid.css"><link rel="stylesheet\talternate" href="tab.css"><link rel="notstylesheet" href="other.css"><script type="application/json" src="data.json"></script>')
	types := document_preload_resource_types(document, document.base_url().serialize())
	assert types['https://preload-types.test/dir/valid.css'] == 'stylesheet'
	assert 'https://preload-types.test/dir/tab.css' !in types
	assert 'https://preload-types.test/dir/other.css' !in types
	// Selection of executable script URLs belongs to the separate URL collector.
	// Preserve the classifier's existing role when an image shares a JSON URL.
	assert types['https://preload-types.test/dir/data.json'] == 'script'
}

fn test_preload_resource_types_rebuild_after_live_dom_and_scripting_policy_changes() {
	mut document := preload_resource_type_test_document('<!doctype html><link id="sheet" rel="stylesheet" href="shared"><script id="script" src="shared"></script>')
	base := document.base_url().serialize()
	before := document_preload_resource_types(document, base)
	assert before['https://preload-types.test/dir/shared'] == 'stylesheet'
	mut sheet := document.get_element_by_id('sheet') or { panic('missing link') }
	sheet.set_attribute_value('rel', 'alternate')
	changed := document_preload_resource_types(document, base)
	assert changed['https://preload-types.test/dir/shared'] == 'script'
	mut script := document.get_element_by_id('script') or { panic('missing script') }
	script.set_attribute_value('src', '../changed.js')
	moved := document_preload_resource_types(document, base)
	assert 'https://preload-types.test/dir/shared' !in moved
	assert moved['https://preload-types.test/changed.js'] == 'script'
	document.set_scripting_enabled_by_embedder(false)
	assert document_preload_resource_types(document, base).len == 0
	assert before['https://preload-types.test/dir/shared'] == 'stylesheet'
}
