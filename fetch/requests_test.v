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
