module main

import adblock
import css
import dom
import html
import platform

fn failed_stylesheet_document(two_links bool) &dom.Document {
	address := dom.URL{ value: 'https://failed-stylesheet.test/page' }
	second := if two_links { '<link id="second" rel="stylesheet" href="late.css">' } else { '' }
	mut document := html.parse_navigation_document('<!doctype html><link id="first" rel="stylesheet" href="late.css">${second}<p id="text">visible</p>', address, address.origin(), none) or { panic(err) }
	mut navigable := &dom.Navigable{ active_document_: document, is_top_level_traversable_: true }
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	assert document.is_fully_active()
	document.set_scripting_enabled_by_embedder(false)
	document.set_viewport_rect(dom.Rect{ width: 320, height: 200 })
	return document
}

fn test_failed_new_stylesheet_completion_preserves_layout_and_delivers_error() {
	mut document := failed_stylesheet_document(false)
	document.enable_native_storage()
	defer { document.finalize() }
	address := 'https://failed-stylesheet.test/late.css'
	mut app := BrowserApp{
		document: document
		script_stylesheet_scan_version: max_u64
		background_resource_results: chan PreloadedResource{cap: 1}
		script_stylesheet_requests: {address: true}
	}
	assert !app.request_script_inserted_stylesheets()
	app.relayout(320, 200 + app.chrome_height())
	before := document.layout_root
	link := document.get_element_by_id('first') or { panic('missing link') }
	model := html.html_link_element_model_for_dom_element(unsafe { &dom.HTMLLinkElement(link) })
	errors := model.event_count('error')
	loads := model.event_count('load')
	mut scratch := platform.begin_thread_scratch('failed stylesheet completion')
	app.background_resource_results <- PreloadedResource{
		url: address.clone()
		error: 'HTTP 404'.clone()
		source_url: document.url.serialize().clone()
		request_type: 'stylesheet'.clone()
	}
	app.poll_background_resources()
	scratch.finish()
	assert voidptr(document.layout_root) == voidptr(before)
	assert css.style_sheet_for_owner_node(document, link) == none
	assert model.event_count('error') == errors + 1
	assert model.event_count('load') == loads
	assert app.script_stylesheet_responses[address].error == 'HTTP 404'
	assert app.script_stylesheet_links[link.as_node().unique_id()] == address
	assert !app.request_script_inserted_stylesheets()
}

fn test_failed_stylesheet_replacement_removes_each_owned_sheet_and_restyles() {
	mut document := failed_stylesheet_document(true)
	defer { document.finalize() }
	address := 'https://failed-stylesheet.test/late.css'
	mut app := BrowserApp{
		document: document
		script_stylesheet_scan_version: max_u64
		background_resource_results: chan PreloadedResource{cap: 1}
		script_stylesheet_requests: {address: true}
	}
	// Initial navigation installs link-owned sheets without the separate legacy
	// script-response text cache. Exercise removal of those existing sheets.
	for id in ['first', 'second'] {
		link := document.get_element_by_id(id) or { panic('missing link') }
		complete_browser_link_stylesheet(link, PreloadedResource{
			url: address
			body: '#text { display: none }'
			request_type: 'stylesheet'
		})
	}
	app.relayout(320, 200 + app.chrome_height())
	text := document.get_element_by_id('text') or { panic('missing text') }
	assert css.up_to_date_computed_properties_for_element(text).display().is_none()
	for id in ['first', 'second'] {
		link := document.get_element_by_id(id) or { panic('missing link') }
		assert css.style_sheet_for_owner_node(document, link) != none
	}
	app.background_resource_results <- PreloadedResource{
		url: address
		error: 'HTTP 404'
		request_type: 'stylesheet'
	}
	app.poll_background_resources()
	assert !css.up_to_date_computed_properties_for_element(text).display().is_none()
	for id in ['first', 'second'] {
		link := document.get_element_by_id(id) or { panic('missing link') }
		assert css.style_sheet_for_owner_node(document, link) == none
		model := html.html_link_element_model_for_dom_element(unsafe { &dom.HTMLLinkElement(link) })
		assert model.event_count('error') >= 1
	}
}

fn test_retained_and_navigation_failed_stylesheets_complete_without_reporting_a_sheet_change() {
	for from_navigation in [false, true] {
		mut document := failed_stylesheet_document(true)
		address := 'https://failed-stylesheet.test/late.css'
		failure := PreloadedResource{ url: address, error: 'HTTP 404', request_type: 'stylesheet' }
		mut app := BrowserApp{ document: document, script_stylesheet_scan_version: max_u64, background_resource_results: chan PreloadedResource{cap: 1} }
		if from_navigation {
			app.navigation_preloaded_resources[address] = failure
		} else {
			app.script_stylesheet_responses[address] = failure
		}
		mut initial_errors := map[string]int{}
		for id in ['first', 'second'] {
			link := document.get_element_by_id(id) or { panic('missing link') }
			model := html.html_link_element_model_for_dom_element(unsafe { &dom.HTMLLinkElement(link) })
			initial_errors[id] = model.event_count('error')
		}
		assert !app.request_script_inserted_stylesheets()
		for id in ['first', 'second'] {
			link := document.get_element_by_id(id) or { panic('missing link') }
			assert css.style_sheet_for_owner_node(document, link) == none
			model := html.html_link_element_model_for_dom_element(unsafe { &dom.HTMLLinkElement(link) })
			assert model.event_count('error') == initial_errors[id] + 1
			assert app.script_stylesheet_links[link.as_node().unique_id()] == address
		}
		assert app.background_resource_results.len == 0
		document.finalize()
	}
}

fn test_mime_rejected_new_stylesheet_does_not_report_a_sheet_change() {
	mut document := failed_stylesheet_document(false)
	defer { document.finalize() }
	mut link := document.get_element_by_id('first') or { panic('missing link') }
	link.set_attribute_value('href', 'mime.css')
	address := 'https://failed-stylesheet.test/mime.css'
	mut app := BrowserApp{ document: document, script_stylesheet_requests: {address: true} }
	native_link := unsafe { &dom.HTMLLinkElement(link) }
	model := html.html_link_element_model_for_dom_element(native_link)
	initial_errors := model.event_count('error')
	assert !app.install_script_inserted_stylesheet(PreloadedResource{
		url: address
		body: '<html>not CSS</html>'
		request_type: 'stylesheet'
		response_headers: [adblock.ResponseHeader{ name: 'Content-Type', value: 'text/html; charset=utf-8' }]
	})
	assert native_link.linked_style_sheet_ == unsafe { nil }
	assert model.sheet() == none
	assert model.event_count('error') == initial_errors + 1
}
