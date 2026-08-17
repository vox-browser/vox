module xhr

fn test_open_method_url_header_and_send_state_validation() {
	mut request := XMLHttpRequest.construct(.window, 'https://example.test/base')
	request.open('get', '/data', true, none, none)!
	assert request.state == .opened
	assert request.request_method == 'GET'
	assert request.request_url == 'https://example.test/data'
	assert request.events.last().type_ == 'readystatechange'
	request.set_request_header('X-Test', ' one ')!
	request.set_request_header('x-test', 'two')!
	assert request.author_request_headers[0].value == 'one, two'
	request.set_request_header('Cookie', 'secret')!
	assert request.author_request_headers.len == 1
	for method in ['bad method', 'TRACE'] {
		if _ := request.open(method, '/x', true, none, none) {
			assert false
		} else {
			assert err.msg().starts_with('SyntaxError:') || err.msg().starts_with('SecurityError:')
		}
	}
	request.open('POST', '/submit', true, none, none)!
	request.send_text('body')!
	assert request.send_flag
	assert request.request_body.bytestr() == 'body'
	assert request.author_request_headers.any(it.name == 'Content-Type')
	if _ := request.send() {
		assert false
	} else {
		assert err.msg().starts_with('InvalidStateError:')
	}
}

fn test_open_uses_url_parser_credentials_and_active_window_check() {
	mut request := XMLHttpRequest.construct(.window, 'https://example.test/a/base')
	request.open('GET', '../data?x=1', true, 'a b', 'p@ss')!
	assert request.request_url == 'https://a%20b:p%40ss@example.test/data?x=1'
	request.window_fully_active = false
	if _ := request.open('GET', '/nope', true, none, none) {
		assert false
	} else {
		assert err.msg().starts_with('InvalidStateError:')
	}
}

fn test_header_validation_forbidden_overrides_and_present_empty_body() {
	mut request := XMLHttpRequest.construct(.window, 'https://example.test/')
	request.open('POST', '/data', true, none, none)!
	request.set_request_header('Access-Control-Request-Private-Network', 'true')!
	request.set_request_header('X-HTTP-Method-Override', 'GET, TRACE')!
	assert request.author_request_headers.len == 0
	if _ := request.set_request_header('X-Bad', 'a\x00b') {
		assert false
	} else {
		assert err.msg().starts_with('SyntaxError:')
	}
	request.set_request_header('Content-Type', 'text/plain;charset=latin1')!
	request.send_text('')!
	assert request.request_body_present
	assert request.request_body.len == 0
	assert request.header('content-type')? == 'text/plain;charset=UTF-8'
	assert !request.upload_complete
}

fn test_upload_boundary_dispatches_progress_load_and_loadend() {
	mut request := XMLHttpRequest.construct(.window, 'https://example.test/')
	request.open('POST', '/upload', true, none, none)!
	request.upload_object.listeners['progress'] = true
	request.send_text('body')!
	assert request.upload_object.events.map(it.type_) == ['loadstart']
	request.receive_upload_chunk_length(4)
	request.complete_upload()
	assert request.upload_object.events.map(it.type_) == ['loadstart', 'progress', 'progress',
		'load', 'loadend']
	assert request.upload_complete
}

fn test_response_state_events_headers_and_text() {
	mut request := XMLHttpRequest.construct(.window, 'https://example.test/')
	request.open('GET', '/data', true, none, none)!
	request.send()!
	request.receive_headers(MockResponse{
		url:         'https://example.test/data#fragment'
		status:      200
		status_text: 'OK'
		headers:     [
			ResponseHeader{
				name:  'X-Z'
				value: 'z'
			},
			ResponseHeader{
				name:  'content-length'
				value: '5'
			},
			ResponseHeader{
				name:  'X-A'
				value: 'a'
			},
			ResponseHeader{
				name:  'x-a'
				value: 'b'
			},
		]
	})!
	assert request.state == .headers_received
	request.receive_chunk('hello'.bytes())
	assert request.state == .loading
	assert request.response_text()! == 'hello'
	request.complete_response()!
	assert request.state == .done
	assert request.status() == 200
	assert request.status_text() == 'OK'
	assert request.response_url() == 'https://example.test/data'
	assert request.get_response_header('X-A')? == 'a, b'
	assert request.get_all_response_headers().starts_with('content-length: 5\r\nX-A: a, b\r\n')
	assert request.events.last().type_ == 'loadend'
	assert request.events.last().length_computable
}

fn test_abort_timeout_credentials_and_gc_lifetime() {
	mut request := XMLHttpRequest.construct(.window, 'https://example.test/')
	request.set_with_credentials(true)!
	request.open('POST', '/x', true, none, none)!
	request.listeners['abort'] = true
	request.send_text('x')!
	assert request.must_survive_garbage_collection()
	request.abort()
	assert request.state == .unsent
	assert request.events.any(it.type_ == 'abort')
	assert !request.must_survive_garbage_collection()
	request.open('GET', '/x', true, none, none)!
	request.send()!
	request.timeout_request()!
	assert request.events.any(it.type_ == 'timeout')
}

fn test_network_errors_are_handled_before_headers_and_sync_errors_throw() {
	mut request := XMLHttpRequest.construct(.window, 'https://example.test/')
	request.open('GET', '/x', true, none, none)!
	request.send()!
	request.receive_headers(MockResponse{ network_error: 'offline' })!
	assert request.state == .done
	assert request.events.map(it.type_).contains('error')
	assert request.response_text()! == ''

	mut synchronous := XMLHttpRequest.construct(.window, 'https://example.test/')
	synchronous.open('GET', '/x', false, none, none)!
	synchronous.send()!
	if _ := synchronous.receive_headers(MockResponse{ network_error: 'offline' }) {
		assert false
	} else {
		assert err.msg() == 'NetworkError: offline'
	}
}
