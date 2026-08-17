module fetch

import dom

fn test_request_defaults() {
	request := Request.create()
	assert request.method == 'GET'
	assert request.mode == .no_cors
	assert request.credentials_mode == .same_origin
	assert request.cache_mode == .default
	assert request.redirect_mode == .follow
	assert request.response_tainting == .basic
	assert request.priority == .auto
	assert request.service_workers_mode == .all
	assert request.referrer.sentinel == .client
	assert request.origin.is_client == true
	assert request.policy_container == .client
	assert request.redirect_count == u8(0)
	assert request.body.kind == .empty
	assert request.url_list.len == 0
}

fn test_request_url_and_current_url() {
	mut request := Request.create()
	// url() is the first URL and current_url() the last (after redirects the list grows).
	request.url_list << dom.URL{
		value: 'https://example.com/a'
	}
	request.url_list << dom.URL{
		value: 'https://example.com/b'
	}
	assert request.url().value == 'https://example.com/a'
	assert request.current_url().value == 'https://example.com/b'
}

fn test_request_is_mutable_record() {
	mut request := Request.create()
	request.method = 'POST'
	request.mode = .cors
	request.credentials_mode = .include
	request.destination = .script
	request.body = RequestBody{
		kind:  .bytes
		bytes: 'payload'.bytes()
	}
	assert request.method == 'POST'
	assert request.mode == .cors
	assert request.credentials_mode == .include
	assert request.destination? == .script
	assert request.body.bytes.bytestr() == 'payload'
}

fn test_request_classification_clone_range_and_strings() {
	mut request := Request.create()
	request.destination = .script
	request.url_list = [dom.URL{'https://example.test/a'}, dom.URL{'https://example.test/b'}]
	request.origin = RequestOrigin{
		is_client: false
		origin:    dom.Origin{'https://example.test'}
	}
	assert request.is_subresource_request()
	assert !request.is_navigation_request()
	request.add_range_header(2, u64(5))!
	assert request.header_list.get('Range')? == 'bytes=2-5'
	clone := request.clone()
	assert clone != request
	assert clone.url_list == request.url_list
	assert clone.header_list.get('Range')? == 'bytes=2-5'
	assert request_destination_to_string(.audio_worklet) == 'audioworklet'
	assert translate_potential_destination('fetch') == none
	assert translate_potential_destination('worker')? == Destination.worker
	assert request_mode_to_string(.same_origin) == 'same-origin'
	assert request_priority_from_string('HIGH')? == Priority.high
}

fn test_request_origin_header_and_redirect_taint() {
	mut request := Request.create()
	request.method = 'POST'
	request.origin = RequestOrigin{
		is_client: false
		origin:    dom.Origin{'https://example.test'}
	}
	request.url_list = [dom.URL{'https://example.test/a'}]
	request.referrer_policy = 'strict-origin-when-cross-origin'
	request.add_origin_header()
	assert request.header_list.get('Origin')? == 'https://example.test'
	assert request.redirect_taint() == .same_origin
	request.url_list << dom.URL{'https://other.test/b'}
	assert request.redirect_taint() == .same_origin
	request.url_list << dom.URL{'https://third.test/c'}
	assert request.redirect_taint() == .cross_site
	assert request.serialize_origin() == 'null'
}
