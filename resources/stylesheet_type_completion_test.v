// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

module main

import css
import dom
import html
import platform

fn stylesheet_type_completion_document() !(&dom.Document, &dom.Element) {
	mut document := dom.Document.create(dom.URL{ value: 'https://stylesheet-type.test/' })
	document.set_document_type(.html)
	document.set_content_type('text/html')
	document.set_origin(document.url.origin())
	document.populate_with_html_head_and_body()!
	// Keep the document in the parser's head phase so the stylesheet blocks
	// rendering as well as scripts and document load completion.
	body := document.body() or { return error('missing body') }
	mut body_node := unsafe { &dom.Element(body) }.as_node()
	body_node.remove(false)
	assert document.allows_adding_render_blocking_elements()
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

fn test_script_stylesheet_completion_shares_its_owned_response_with_the_link() {
	for from_browser_cache in [false, true] {
		mut document, link := stylesheet_type_completion_document()!
		document.enable_native_storage()
		defer {
			document.finalize()
			document.release_native_storage()
		}
		address := 'https://stylesheet-type.test/pending.css'
		expected := 'p { color: rebeccapurple }'
		mut app := BrowserApp{
			document: document
			script_stylesheet_requests: {address: true}
		}
		input := platform.begin_thread_scratch('stylesheet response input test')
		defer { input.finish() }
		body := expected.clone()
		input.leave()
		response := PreloadedResource{
			url:          address
			body:         body
			source_url:   document.url.serialize()
			final_url:    address
			request_type: 'stylesheet'
		}
		supplied := if from_browser_cache { persistent_preloaded_resource(response) } else { response }
		assert app.install_script_inserted_stylesheet(supplied)
		input.finish()

		retained := app.script_stylesheet_responses[address].body
		model := html.html_link_element_model_for_dom_element(unsafe { &dom.HTMLLinkElement(link) })
		loaded := model.sheet()?
		assert loaded == expected
		assert voidptr(loaded.str) == voidptr(retained.str)
		assert voidptr(retained.str) != voidptr(body.str)
		if from_browser_cache {
			assert voidptr(loaded.str) == voidptr(supplied.body.str)
		}
		sheet := css.style_sheet_for_owner_node(document, link)?
		assert sheet.href()? == address
		assert sheet.base_url_for_bindings()? == address
		assert sheet.css_rules().length() == 1
		assert sheet.css_rules().rules[0].css_text().starts_with('p {')
		assert model.event_count('load') == 1
	}
}

fn test_stylesheet_completion_keeps_mutable_byte_input_independent() {
	expected := 'p { color: blue }\x00/* trailing response bytes */'
	mut body := expected.bytes()
	mut model := html.HTMLLinkElementModel.create(dom.URL{value: 'https://stylesheet-type.test/'})
	model.set_rel('stylesheet')
	model.set_href('/pending.css')
	model.process_stylesheet_resource(true, html.LinkResourceResponse{
		content_type: 'text/css'
		body: body
	})
	body[0] = `a`
	assert model.sheet()? == expected
}
