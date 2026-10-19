module main

import css
import dom
import html

fn external_styles_test_document(markup string) &dom.Document {
	address := dom.URL{value: 'https://styles.test/board/'}
	mut document := html.parse_navigation_document(markup, address, address.origin(), none) or {
		panic(err)
	}
	document.set_scripting_enabled_by_embedder(false)
	return document
}

fn external_styles_test_resources(names []string) map[string]PreloadedResource {
	mut resources := map[string]PreloadedResource{}
	for name in names {
		address := 'https://cdn.styles.test/${name}.css'
		resources[address] = PreloadedResource{
			url:          address
			body:         '.${name} { color: red }'
			source_url:   'https://styles.test/board/'
			final_url:    address
			request_type: 'stylesheet'
		}
	}
	return resources
}

// Each inlined sheet records its response URL; untouched author styles do not.
fn external_styles_test_order(document &dom.Document) []string {
	mut order := []string{}
	for element in css.query_selector_all(unsafe { &dom.Node(document) }, 'link, style') {
		if element.local_name() == 'link' {
			order << 'link:' + element.get_attribute_value('title')
		} else {
			source := element.get_attribute_value('data-libweb-v-source-url')
			order << if source == '' { 'author' } else { source.all_after_last('/') }
		}
	}
	return order
}

fn test_alternate_link_stylesheets_apply_only_for_the_preferred_set() {
	mut document := external_styles_test_document('<!doctype html><head>' +
		'<link rel="stylesheet" title="switch" href="//cdn.styles.test/main.css">' +
		'<link rel="alternate stylesheet" href="//cdn.styles.test/main.css" title="Main">' +
		'<link rel="alternate stylesheet" href="//cdn.styles.test/dark.css" title="Dark">' +
		'<link rel="Alternate  StyleSheet" href="//cdn.styles.test/chosen.css" title="switch">' +
		'<link rel="alternate stylesheet" href="//cdn.styles.test/untitled.css">' +
		'<link rel="stylesheet" disabled href="//cdn.styles.test/disabled.css">' +
		'<link rel="stylesheet" href="//cdn.styles.test/plain.css">' +
		'</head><p>board</p>')
	defer { document.finalize() }
	root := unsafe { &dom.Node(document) }
	assert preferred_style_sheet_set_name(root) == 'switch'
	assert document_preload_resource_urls(document, document.base_url().serialize()) == [
		'https://cdn.styles.test/main.css',
		'https://cdn.styles.test/chosen.css',
		'https://cdn.styles.test/plain.css',
	]
	messages := install_external_styles(document, document.base_url().serialize(),
		external_styles_test_resources(['main', 'dark', 'chosen', 'untitled', 'disabled', 'plain']))
	assert messages == []
	assert external_styles_test_order(document) == ['link:switch', 'main.css', 'link:Main',
		'link:Dark', 'link:switch', 'chosen.css', 'link:', 'link:', 'link:', 'plain.css']
}

fn test_inlined_link_stylesheets_keep_tree_order_before_later_author_styles() {
	mut document := external_styles_test_document('<!doctype html><head>' +
		'<link rel="stylesheet" href="//cdn.styles.test/site.css">' +
		'<style>.site { color: green }</style></head><body>' +
		'<link rel="stylesheet" href="//cdn.styles.test/late.css"><p>board</p></body>')
	defer { document.finalize() }
	messages := install_external_styles(document, document.base_url().serialize(),
		external_styles_test_resources(['site', 'late']))
	assert messages == []
	assert external_styles_test_order(document) == ['link:', 'site.css', 'author', 'link:',
		'late.css']
}

fn test_titled_author_style_names_the_preferred_set_before_later_links() {
	mut document := external_styles_test_document('<!doctype html><head>' +
		'<style title="Night">p { color: white }</style>' +
		'<link rel="stylesheet" title="Day" href="//cdn.styles.test/day.css">' +
		'<link rel="alternate stylesheet" title="Night" href="//cdn.styles.test/night.css">' +
		'</head><p>board</p>')
	defer { document.finalize() }
	root := unsafe { &dom.Node(document) }
	assert preferred_style_sheet_set_name(root) == 'Night'
	links := css.query_selector_all(root, 'link')
	assert !link_stylesheet_applies(links[0], 'Night')
	assert link_stylesheet_applies(links[1], 'Night')
	assert !link_stylesheet_applies(links[1], 'night')
}

fn test_preferred_stylesheet_set_discovery_observes_late_titles_and_reordering() {
	mut document := external_styles_test_document('<!doctype html><head><style id="first"></style><style id="second"></style></head><a title="other">link</a>')
	defer { document.finalize() }
	root := document.as_node()
	assert !document.may_have_tag_attribute('style', 'title')
	assert preferred_style_sheet_set_name(root) == ''
	mut first := document.get_element_by_id('first') or { panic('first') }
	mut second := document.get_element_by_id('second') or { panic('second') }
	second.set_attribute_value('title', 'Later')
	assert preferred_style_sheet_set_name(root) == 'Later'
	first.set_attribute_value('title', 'Earlier')
	assert preferred_style_sheet_set_name(root) == 'Earlier'
	first.set_attribute_value('title', '')
	assert preferred_style_sheet_set_name(root) == 'Later'
	second.remove_attribute('title')
	assert preferred_style_sheet_set_name(root) == ''
	second.set_attribute_value('title', 'Restored')
	assert preferred_style_sheet_set_name(root) == 'Restored'
}
