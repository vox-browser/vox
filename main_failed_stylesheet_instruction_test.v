module main

import css
import dom
import html
import processmetrics

fn test_repeated_failed_stylesheet_completions_keep_the_document_usable() {
	address := dom.URL{ value: 'https://failed-stylesheet-probe.test/page' }
	mut markup := '<!doctype html><link id="sheet" rel="stylesheet" href="late.css"><main>'
	for index in 0 .. 128 { markup += '<p>Row ${index}: unchanged content</p>' }
	markup += '</main>'
	mut document := html.parse_navigation_document(markup, address, address.origin(), none) or { panic(err) }
	document.set_scripting_enabled_by_embedder(false)
	defer { document.finalize() }
	resource_url := 'https://failed-stylesheet-probe.test/late.css'
	mut app := BrowserApp{
		document: document
		background_resource_results: chan PreloadedResource{cap: 1}
		script_stylesheet_requests: {resource_url: true}
	}
	app.request_script_inserted_stylesheets()
	app.relayout(320, 200 + app.chrome_height())
	link := document.get_element_by_id('sheet') or { panic('missing link') }
	model := html.html_link_element_model_for_dom_element(unsafe { &dom.HTMLLinkElement(link) })
	initial_errors := model.event_count('error')
	failure := PreloadedResource{ url: resource_url, error: 'HTTP 404', request_type: 'stylesheet' }
	for _ in 0 .. 8 {
		app.background_resource_results <- failure
		app.poll_background_resources()
	}
	gc_collect()
	$if vox_failed_stylesheet_probe ? {
		start := processmetrics.instruction_snapshot()
		for _ in 0 .. 32 {
			app.background_resource_results <- failure
			app.poll_background_resources()
		}
		instructions := processmetrics.instruction_snapshot().since(start) or { panic('instruction counter unavailable') }
		assert model.event_count('error') == initial_errors + 40
		assert css.style_sheet_for_owner_node(document, link) == none
		assert document.layout_root != unsafe { nil }
		assert app.resource_cache[resource_url].error == 'HTTP 404'
		eprintln('VOX_FAILED_STYLESHEET instructions=${instructions} completions=32 errors=40')
	} $else {
		assert model.event_count('error') == initial_errors + 8
		assert css.style_sheet_for_owner_node(document, link) == none
		assert document.layout_root != unsafe { nil }
		assert app.script_stylesheet_responses[resource_url].error == 'HTTP 404'
	}
}
