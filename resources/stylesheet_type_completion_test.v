// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

module main

import css
import dom
import html

fn stylesheet_type_completion_document() !(&dom.Document, &dom.Element) {
	mut document := dom.Document.create(dom.URL{ value: 'https://stylesheet-type.test/' })
	document.set_document_type(.html)
	document.set_origin(document.url.origin())
	document.populate_with_html_head_and_body()!
	_ = html.WindowModel.create_top_level(document, none, '')!
	mut link := document.create_element('link')!
	link.set_attribute_value('rel', 'stylesheet')
	link.set_attribute_value('href', '/pending.css')
	mut head := document.head() or { return error('missing head') }
	mut head_node := head.as_node()
	head_node.append_child(link.as_node())!
	assert link.as_node().is_browsing_context_connected()
	assert document.is_fully_active()
	return document, link
}

fn test_unsupported_stylesheet_type_releases_blockers_before_native_completion_filters_owner() {
	for failed in [false, true] {
		mut document, mut link := stylesheet_type_completion_document()!
		defer { document.finalize() }
		address := 'https://stylesheet-type.test/pending.css'
		mut app := BrowserApp{
			document: document
			script_stylesheet_scan_version: max_u64
			script_stylesheet_requests: {address: true}
		}
		native_link := unsafe { &dom.HTMLLinkElement(link) }
		mut model := html.html_link_element_model_for_dom_element(native_link)
		model.set_parser_state(true, true)
		// Start from an installed stylesheet before Window load, as in the
		// native adapter. Its next supported type transition starts a load.
		assert app.install_script_inserted_stylesheet(PreloadedResource{
			url: address
			body: 'p { color: red }'
			source_url: document.url.serialize()
			request_type: 'stylesheet'
		})
		assert css.style_sheet_for_owner_node(document, link) != none
		assert !document.anything_is_delaying_the_load_event()
		loads := model.event_count('load')
		errors := model.event_count('error')
		link.set_attribute_value('type', 'text/plain')
		link.set_attribute_value('type', 'text/css')
		assert model.is_stylesheet_loading()
		assert document.has_pending_style_sheet_requests()
		assert document.anything_is_delaying_the_load_event()
		assert document.document_script_blocking_style_sheet_set().any(voidptr(it) == voidptr(link))
		assert document.is_render_blocking_element(link)

		link.set_attribute_value('type', 'text/plain')
		assert !model.is_stylesheet_loading()
		assert !document.has_pending_style_sheet_requests()
		assert !document.anything_is_delaying_the_load_event()
		assert !document.document_script_blocking_style_sheet_set().any(voidptr(it) == voidptr(link))
		assert !document.is_render_blocking_element(link)
		assert !link_stylesheet_applies(link, '')

		// Exercise the real native completion filter: it skips this owner,
		// so process_stylesheet_resource cannot clean up its loading state.
		assert !app.install_script_inserted_stylesheet(PreloadedResource{
			url: address
			body: if failed { '' } else { 'p { color: green }' }
			error: if failed { 'HTTP 404' } else { '' }
			source_url: document.url.serialize()
			request_type: 'stylesheet'
		})
		assert app.script_stylesheet_responses[address].error == if failed { 'HTTP 404' } else { '' }
		assert css.style_sheet_for_owner_node(document, link) == none
		assert model.sheet() == none
		assert model.event_count('load') == loads
		assert model.event_count('error') == errors
		assert !model.is_stylesheet_loading()
		assert !document.has_pending_style_sheet_requests()
		assert !document.anything_is_delaying_the_load_event()
		assert !document.document_script_blocking_style_sheet_set().any(voidptr(it) == voidptr(link))
		assert !document.is_render_blocking_element(link)
	}
}
