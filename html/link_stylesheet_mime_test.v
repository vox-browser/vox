// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

module html

import css
import dom

__global (
	stylesheet_mime_test_fetches int
	stylesheet_mime_test_response_type string
)

fn stylesheet_mime_test_fetch(address dom.URL, _ LinkResourceKind, _ CORSSettingAttribute) !LinkResourceResponse {
	stylesheet_mime_test_fetches++
	return LinkResourceResponse{
		content_type: stylesheet_mime_test_response_type
		body: 'p { color: red }'.bytes()
		url: address
	}
}

// Ladybird 70df302eeebc40488afc780ca53a7307f24fe5f0.
fn test_link_type_never_overrides_response_content_type() {
	for content_type in ['text/plain', 'text/css; charset=utf-8', '', 'not-a-mime-type'] {
		stylesheet_mime_test_response_type = content_type
		mut model := HTMLLinkElementModel.create(dom.URL{value: 'https://styles.test/'})
		model.set_rel('stylesheet')
		model.set_href('/resource')
		model.set_type('text/css; charset=utf-8')
		model.set_fetch_hook(stylesheet_mime_test_fetch)
		model.fetch_and_process_linked_resource()
		assert (model.sheet() != none) == (content_type != 'text/plain')
		assert model.event_count(if content_type == 'text/plain' { 'error' } else { 'load' }) == 1
		assert !model.document_load_event_delaying_
	}
}

fn test_stylesheet_type_distinguishes_absent_empty_and_parameterized_values() {
	assert is_supported_style_sheet_type_attribute(none)
	for value in ['', 'text/plain', 'invalid'] {
		assert !is_supported_style_sheet_type_attribute(value)
		stylesheet_mime_test_fetches = 0
		mut model := HTMLLinkElementModel.create(dom.URL{value: 'https://styles.test/'})
		model.set_rel('stylesheet')
		model.set_href('/resource')
		model.set_type(value)
		model.set_fetch_hook(stylesheet_mime_test_fetch)
		model.fetch_and_process_linked_resource()
		assert stylesheet_mime_test_fetches == 0
		assert model.sheet() == none
		assert !model.document_load_event_delaying_
	}
	assert is_supported_style_sheet_type_attribute('TEXT/CSS; charset=utf-8')
}

fn stylesheet_mime_test_document() !(&dom.Document, &dom.Element, &HTMLLinkElementModel) {
	mut document := dom.Document.create(dom.URL{value: 'https://styles.test/'})
	document.set_document_type(.html)
	document.set_origin(document.url.origin())
	document.populate_with_html_head_and_body()!
	_ = WindowModel.create_top_level(document, none, '')!
	mut element := document.create_element('link')!
	element.set_attribute_value('rel', 'stylesheet')
	element.set_attribute_value('href', '/resource')
	mut head := document.head() or { return error('missing head') }
	mut head_node := head.as_node()
	head_node.append_child(element.as_node())!
	mut model := html_link_element_model_for_dom_element(unsafe { &dom.HTMLLinkElement(element) })
	model.set_fetch_hook(stylesheet_mime_test_fetch)
	return document, element, model
}

fn test_dom_stylesheet_type_changes_remove_and_refetch_without_reloading_supported_types() {
	stylesheet_mime_test_fetches = 0
	stylesheet_mime_test_response_type = 'text/css'
	mut document, mut element, mut model := stylesheet_mime_test_document()!
	defer { document.finalize() }
	model.fetch_and_process_linked_resource()
	assert stylesheet_mime_test_fetches == 1
	sheet := css.style_sheet_for_owner_node(document, element)?
	element.set_attribute_value('type', 'text/css; charset=utf-8')
	assert stylesheet_mime_test_fetches == 1
	assert voidptr(css.style_sheet_for_owner_node(document, element)?) == voidptr(sheet)
	element.set_attribute_value_ns('type', 'text/plain', 'test', 'urn:test')
	assert stylesheet_mime_test_fetches == 1
	assert voidptr(css.style_sheet_for_owner_node(document, element)?) == voidptr(sheet)
	element.set_attribute_value('type', 'text/plain')
	assert model.sheet() == none
	assert css.style_sheet_for_owner_node(document, element) == none
	element.remove_attribute('type')
	assert stylesheet_mime_test_fetches == 2
	assert css.style_sheet_for_owner_node(document, element) != none
}

fn test_unsupported_type_cancels_pending_stylesheet_load_state() {
	mut document, mut element, mut model := stylesheet_mime_test_document()!
	defer { document.finalize() }
	// Exercise the parser's head phase, before a body allows rendering.
	document.set_content_type('text/html')
	body := document.body() or { panic('missing body') }
	mut body_node := unsafe { &dom.Element(body) }.as_node()
	body_node.remove(false)
	assert document.allows_adding_render_blocking_elements()
	model.set_fetch_hook(none)
	model.set_external_stylesheet_fetcher(true)
	model.set_parser_state(true, true)
	model.fetch_and_process_linked_resource()
	assert model.is_stylesheet_loading()
	assert model.document_load_event_delaying_
	assert document.has_pending_style_sheet_requests()
	assert document.document_script_blocking_style_sheet_set().any(voidptr(it) == voidptr(element))
	assert document.is_render_blocking_element(element)

	element.set_attribute_value('type', 'text/plain')
	assert !model.is_stylesheet_loading()
	assert !model.document_load_event_delaying_
	assert !document.has_pending_style_sheet_requests()
	assert !document.document_script_blocking_style_sheet_set().any(voidptr(it) == voidptr(element))
	assert !document.is_render_blocking_element(element)
}

fn test_link_mime_quirk_is_limited_to_quirks_documents_and_same_origin_response_urls() {
	for quirks in [false, true] {
		for same_origin in [false, true] {
			mut document, element, mut model := stylesheet_mime_test_document()!
			defer { document.finalize() }
			document.set_quirks_mode(if quirks { .yes } else { .no })
			model.process_stylesheet_resource(true, LinkResourceResponse{
				content_type: 'text/plain'
				body: 'p { color: red }'.bytes()
				url: dom.URL{value: if same_origin { 'https://styles.test/resource' } else { 'https://other.test/resource' }}
			})
			assert (css.style_sheet_for_owner_node(document, element) != none) == (quirks && same_origin)
		}
	}
}

fn test_unsupported_type_cannot_apply_an_already_started_response() {
	mut model := HTMLLinkElementModel.create(dom.URL{value: 'https://styles.test/'})
	model.set_rel('stylesheet')
	mut request := LinkRequest{url: dom.URL{value: 'https://styles.test/resource'}}
	assert model.stylesheet_linked_resource_fetch_setup_steps(mut request)
	model.set_type('')
	model.process_stylesheet_resource(true, LinkResourceResponse{content_type: 'text/css', body: 'p {color:red}'.bytes()})
	assert model.sheet() == none
	assert !model.document_load_event_delaying_
}
