module fetch

import dom

fn test_request_object_constructor_guards_and_getters() {
	object := RequestObject.construct(RequestInput{ url: dom.URL{'https://example.test/data'} }, RequestInit{
		method:    'post'
		body:      BodyInit{
			kind: .string_
			text: 'hello'
		}
		keepalive: true
	})!
	assert object.method() == 'POST'
	assert object.url() == 'https://example.test/data'
	assert object.keepalive()
	assert object.headers().get('Content-Type')? == 'text/plain;charset=UTF-8'
	assert object.signal() == object.signal()
	clone := object.clone()!
	assert clone != object
	assert clone.method() == 'POST'
}

fn test_request_object_rejects_invalid_combinations() {
	if _ := RequestObject.construct(RequestInput{ url: dom.URL{'https://example.test/'} }, RequestInit{
		method: 'TRACE'
	})
	{
		assert false
	}
	if _ := RequestObject.construct(RequestInput{ url: dom.URL{'https://example.test/'} }, RequestInit{
		method: 'GET'
		body:   BodyInit{
			kind: .string_
			text: 'x'
		}
	})
	{
		assert false
	}
	if _ := RequestObject.construct(RequestInput{ url: dom.URL{'https://example.test/'} }, RequestInit{
		cache: .only_if_cached
		mode:  .cors
	})
	{
		assert false
	}
	if _ := RequestObject.construct(RequestInput{ url: dom.URL{'https://example.test/'} }, RequestInit{
		method: 'G\tET'
	})
	{
		assert false
	}
	if _ := RequestObject.construct(RequestInput{ url: dom.URL{'https://example.test/'} }, RequestInit{
		mode:   .no_cors
		body:   BodyInit{
			kind: .readable_stream
		}
		duplex: .half
	})
	{
		assert false
	}
}

fn test_request_constructor_fallbacks_filtering_and_clone_body_independence() {
	object := RequestObject.construct(RequestInput{
		url: dom.URL{'https://example.test/data'}
	}, RequestInit{})!
	assert object.mode() == .cors
	assert object.internal_request().unsafe_request
	assert object.internal_request().initiator_type? == .fetch
	with_headers := RequestObject.construct(RequestInput{
		url: dom.URL{'https://example.test/data'}
	}, RequestInit{
		headers: [HeaderPair{ name: 'Cookie', value: 'secret' },
			HeaderPair{ name: 'X-Visible', value: 'yes' }]
	})!
	assert !with_headers.headers().has('Cookie')!
	assert with_headers.headers().get('X-Visible')? == 'yes'
	cross_origin_referrer := RequestObject.construct(RequestInput{
		url: dom.URL{'https://example.test/data'}
	}, RequestInit{
		referrer: 'https://other.test/source'
	})!
	assert cross_origin_referrer.referrer() == 'about:client'
	with_body := RequestObject.construct(RequestInput{
		url: dom.URL{'https://example.test/data'}
	}, RequestInit{
		method: 'POST'
		body:   BodyInit{
			kind: .string_
			text: 'payload'
		}
	})!
	clone := with_body.clone()!
	assert clone.body_mixin().text()! == 'payload'
	assert !with_body.body_mixin().body_used()
}

fn test_response_object_constructor_factories_and_clone() {
	object := ResponseObject.construct(BodyInit{ kind: .string_, text: 'hello' }, ResponseInit{
		status:      201
		status_text: 'Created'
	})!
	assert object.status() == 201
	assert object.ok()
	assert object.headers().get('Content-Type')? == 'text/plain;charset=UTF-8'
	assert object.clone()!.status() == 201
	error_object := ResponseObject.error()
	assert error_object.type_() == .error
	redirect := ResponseObject.redirect('https://example.test/next', 302)!
	assert redirect.status() == 302
	assert redirect.headers().get('Location')? == 'https://example.test/next'
	json_object := ResponseObject.json('{"ok":true}', ResponseInit{})!
	assert json_object.headers().get('Content-Type')? == 'application/json'
}

fn test_response_url_excludes_fragment() {
	mut response := Response.create()
	response.url_list = [dom.URL{'https://example.test/path?q=1#fragment'}]
	object := &ResponseObject{
		response_: response
		headers_:  Headers.from_header_list(response.header_list, .immutable)
	}
	assert object.url() == 'https://example.test/path?q=1'
}

fn test_response_rejects_status_text_and_null_body_status() {
	if _ := ResponseObject.construct(none, ResponseInit{ status: 199 }) { assert false
	 }
	if _ := ResponseObject.construct(BodyInit{ kind: .string_, text: 'x' }, ResponseInit{
		status: 204
	})
	{
		assert false
	}
}
