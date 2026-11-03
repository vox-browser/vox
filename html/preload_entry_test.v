@[has_globals]
module html

import dom

__global consumed_preload_responses []LinkResourceResponse

fn record_consumed_preload_response(response LinkResourceResponse) {
	consumed_preload_responses << response
}

fn preload_entry_test_fetch(_ dom.URL, kind LinkResourceKind, _ CORSSettingAttribute) !LinkResourceResponse {
	assert kind == .preload
	return LinkResourceResponse{
		body: [u8(9)]
	}
}

fn test_translate_a_preload_destination_uses_exact_keywords() {
	assert translate_a_preload_destination('fetch')? == ''
	assert translate_a_preload_destination('image')? == 'image'
	assert translate_a_preload_destination('track')? == 'track'
	assert translate_a_preload_destination('IMAGE') == none
	assert translate_a_preload_destination('audio') == none
	assert translate_a_preload_destination('') == none
}

fn test_preload_entry_consumes_a_resolved_response_once() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/page.html' })
	url := dom.dom_url_parse('/app.js', document.base_url(), 'UTF-8') or { panic('Expected a valid preload URL') }
	request := create_potential_cors_request(url, RequestDestination.script, .anonymous, .no)
	mut entry := &PreloadEntry{
		integrity_metadata: 'sha256-test'
	}
	entry.set_response(LinkResourceResponse{
		status: 200
		body: [u8(1), 2, 3]
	})
	store_preloaded_resource(document, create_a_preload_key(request), entry)
	assert document.preloaded_resource_entry_count() == 1
	assert preload_key_storage_key(create_a_preload_key(request)) == preload_key_storage_key(PreloadKey{
		url:url, destination:RequestDestination.script, mode:.cors, credentials_mode:.same_origin
	})

	consumed_preload_responses.clear()
	// Keep the enum type explicit across the optional destination argument.
	assert consume_a_preloaded_resource(document, url, RequestDestination.script, .cors, .same_origin, 'sha256-test', record_consumed_preload_response)
	assert consumed_preload_responses.len == 1
	assert consumed_preload_responses[0].body == [u8(1), 2, 3]
	assert document.preloaded_resource_entry_count() == 0
	assert !consume_a_preloaded_resource(document, url, RequestDestination.script, .cors, .same_origin, 'sha256-test', record_consumed_preload_response)
}

fn test_preload_entry_delivers_a_response_that_was_pending_at_consumption() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	url := dom.dom_url_parse('/style.css', document.base_url(), 'UTF-8') or { panic('Expected a valid preload URL') }
	request := create_potential_cors_request(url, RequestDestination.style, .no_cors, .no)
	mut entry := &PreloadEntry{}
	store_preloaded_resource(document, create_a_preload_key(request), entry)
	consumed_preload_responses.clear()

	assert consume_a_preloaded_resource(document, url, .style, .no_cors, .include, '', record_consumed_preload_response)
	assert consumed_preload_responses.len == 0
	entry.set_response(LinkResourceResponse{
		status: 204
	})
	assert consumed_preload_responses.len == 1
	assert consumed_preload_responses[0].status == 204
}

fn test_link_preload_commits_its_entry_to_the_associated_document() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/page.html' })
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'link')!
	mut model := html_link_element_model_for_dom_element(unsafe { &dom.HTMLLinkElement(element) })
	model.set_rel('preload')
	model.set_href('/asset.bin')
	model.set_as('fetch')
	model.set_fetch_hook(preload_entry_test_fetch)
	model.fetch_and_process_linked_preload_resource()
	assert document.preloaded_resource_entry_count() == 1

	url := dom.dom_url_parse('/asset.bin', document.base_url(), 'UTF-8') or { panic('Expected a valid preload URL') }
	consumed_preload_responses.clear()
	assert consume_a_preloaded_resource(document, url, none, .no_cors, .include, '', record_consumed_preload_response)
	assert consumed_preload_responses[0].body == [u8(9)]
}
