module main

import css
import dom
import html

fn svg_use_resource_test_document(markup string) &dom.Document {
	address := dom.URL{value: 'https://sprite.test/page'}
	return html.parse_navigation_document(markup, address,
		html.determine_the_origin(address, html.SandboxingFlagSet{}, none), none) or { panic(err) }
}

fn svg_use_resource_test_instance(element &dom.Element) ?&dom.Element {
	shadow := element.shadow_root() or { return none }
	node := unsafe { &dom.Node(shadow) }.first_child() or { return none }
	return node.as_element()
}

fn test_external_svg_use_preloads_one_body_for_fragments_and_resolves_document_base() {
	mut document := svg_use_resource_test_document('<!doctype html><base href="/assets/"><svg><use href="sprite.svg#one"/><use xlink:href="sprite.svg#two"/><use href="#local"/><use href="https://other.test/sprite.svg#one"/></svg>')
	defer { document.finalize() }
	urls := document_preload_resource_urls(document, document.base_url().serialize())
	assert urls == ['https://sprite.test/assets/sprite.svg']
	foreground := document_svg_image_preload_urls(document, document.base_url().serialize())
	assert 'https://sprite.test/assets/sprite.svg' in foreground
}

fn test_external_svg_use_stays_in_the_initial_barrier_when_scripting_is_enabled() {
	mut document := svg_use_resource_test_document('<!doctype html><svg><use href="sprite.svg#logo"/><image href="photo.png"/></svg>')
	defer { document.finalize() }
	assert document.as_node().is_scripting_enabled()
	initial := document_initial_svg_preload_urls(document, document.base_url().serialize())
	assert 'https://sprite.test/sprite.svg' in initial
	assert 'https://sprite.test/photo.png' !in initial
	document.set_scripting_enabled_by_embedder(false)
	static_initial := document_initial_svg_preload_urls(document, document.base_url().serialize())
	assert 'https://sprite.test/sprite.svg' in static_initial
	assert 'https://sprite.test/photo.png' in static_initial
}

fn test_external_svg_use_clones_symbol_dimensions_and_refreshes_href() {
	mut document := svg_use_resource_test_document('<!doctype html><svg><path id="shape" data-owner="page"/><use id="target" href="sprite.svg#shape" width="40" height="20"/></svg>')
	defer { document.finalize() }
	address := 'https://sprite.test/sprite.svg'
	install_browser_svg_use_resources(document, {address: PreloadedResource{url: address,
		body: '<svg xmlns="http://www.w3.org/2000/svg"><symbol id="shape" viewBox="0 0 20 10" data-owner="sprite"><path d="M0 0H20V10H0Z"/></symbol></svg>'}})
	mut target := document.get_element_by_id('target')?
	instance := svg_use_resource_test_instance(target)?
	assert instance.local_name() == 'symbol' && instance.get_attribute_value('data-owner') == 'sprite'
	assert instance.get_attribute_value('width') == '40' && instance.get_attribute_value('height') == '20'
	assert !target.shadow_root()?.uses_document_style_sheets()
	target.set_attribute_value('href', 'sprite.svg#missing')
	assert svg_use_resource_test_instance(target) == none
	target.set_attribute_value('href', '#shape')
	assert svg_use_resource_test_instance(target)?.get_attribute_value('data-owner') == 'page'
	assert target.shadow_root()?.uses_document_style_sheets()
}

fn test_external_svg_use_nested_references_keep_the_sprite_base_and_cycles_stay_empty() {
	mut document := svg_use_resource_test_document('<!doctype html><svg><path id="path" data-owner="wrong"/><use id="target" href="sprite.svg#nested"/><use id="cycle" href="sprite.svg#cycle"/></svg>')
	defer { document.finalize() }
	address := 'https://sprite.test/sprite.svg'
	install_browser_svg_use_resources(document, {address: PreloadedResource{url: address,
		body: '<svg xmlns="http://www.w3.org/2000/svg"><path id="path" data-owner="sprite" d="M0 0H10V10Z"/><symbol id="nested" viewBox="0 0 10 10"><use href="#path"/></symbol><symbol id="cycle"><use href="#cycle"/></symbol></svg>'}})
	target := document.get_element_by_id('target')?
	instance := svg_use_resource_test_instance(target)?
	nested := css.query_selector_all(instance.as_node(), 'use')[0]
	assert svg_use_resource_test_instance(nested)?.get_attribute_value('data-owner') == 'sprite'
	cycle := document.get_element_by_id('cycle')?
	assert svg_use_resource_test_instance(cycle) == none
}

fn test_external_svg_use_rejects_missing_invalid_and_cross_origin_responses() {
	for resource in [PreloadedResource{url: 'https://sprite.test/sprite.svg', error: 'fetch failed'},
		PreloadedResource{url: 'https://sprite.test/sprite.svg', body: '<html/>'},
		PreloadedResource{url: 'https://sprite.test/sprite.svg', final_url: 'https://other.test/sprite.svg', body: '<svg xmlns="http://www.w3.org/2000/svg"><path id="shape"/></svg>'}] {
		mut document := svg_use_resource_test_document('<!doctype html><svg><use id="target" href="sprite.svg#shape"/></svg>')
		install_browser_svg_use_resources(document, {'https://sprite.test/sprite.svg': resource})
		target := document.get_element_by_id('target')?
		assert svg_use_resource_test_instance(target) == none
		document.finalize()
	}
}
