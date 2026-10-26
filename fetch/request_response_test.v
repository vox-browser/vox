module fetch

import dom
import infra

struct ConstructionTestClient {
	base_url dom.URL
	origin_  dom.Origin
}

fn (client &ConstructionTestClient) fetch_request_client_api_base_url() dom.URL {
	return client.base_url
}

fn (_ &ConstructionTestClient) fetch_request_client_policy_container() RequestPolicyContainer {
	return RequestPolicyContainer{}
}

fn (_ &ConstructionTestClient) fetch_request_client_is_window() bool {
	return false
}

fn (_ &ConstructionTestClient) fetch_request_client_is_top_level_window() bool {
	return false
}

fn (client &ConstructionTestClient) fetch_request_client_origin() dom.Origin {
	return client.origin_
}

fn (_ &ConstructionTestClient) fetch_request_client_document_url() ?dom.URL {
	return none
}

fn (client &ConstructionTestClient) fetch_request_client_creation_url() dom.URL {
	return client.base_url
}

fn (_ &ConstructionTestClient) fetch_request_client_embedder_policy_credentialless() bool {
	return false
}

fn (client &ConstructionTestClient) fetch_request_client_top_level_origin() ?dom.Origin {
	return client.origin_
}

fn (_ &ConstructionTestClient) fetch_request_client_top_level_creation_url() ?dom.URL {
	return none
}

fn (_ &ConstructionTestClient) fetch_request_client_cross_origin_isolated_capability() bool {
	return false
}

fn test_request_object_constructor_guards_and_getters() {
	object := RequestObject.construct(RequestInput{ url: dom.URL{value: 'https://example.test/data'} }, RequestInit{
		method: 'post'
		body: BodyInit{
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

fn test_request_wrappable_constructor_entry_points_use_relevant_settings() {
	client := &ConstructionTestClient{
		base_url: dom.URL{value: 'https://settings.test/base/'}
		origin_: dom.Origin{ value: 'https://settings.test' }
	}
	constructed := Request.create_for_constructor(RequestInput{
		url: dom.URL{value: 'https://example.test/data'}
	}, RequestInit{})!
	assert constructed.url() == 'https://example.test/data'
	with_settings := Request.create_with_settings(client, RequestInput{
		url: dom.URL{value: 'https://example.test/data'}
	}, RequestInit{
		referrer: '../source'
	})!
	assert with_settings.internal_request().client != none
	assert with_settings.referrer() == 'https://settings.test/source'
}

fn test_request_object_rejects_invalid_combinations() {
	if _ := RequestObject.construct(RequestInput{ url: dom.URL{value: 'https://example.test/'} }, RequestInit{
		method: 'TRACE'
	}) {
		assert false
	}
	if _ := RequestObject.construct(RequestInput{ url: dom.URL{value: 'https://example.test/'} }, RequestInit{
		method: 'GET'
		body: BodyInit{
			kind: .string_
			text: 'x'
		}
	}) {
		assert false
	}
	if _ := RequestObject.construct(RequestInput{ url: dom.URL{value: 'https://example.test/'} }, RequestInit{
		cache: .only_if_cached
		mode: .cors
	}) {
		assert false
	}
	if _ := RequestObject.construct(RequestInput{ url: dom.URL{value: 'https://example.test/'} }, RequestInit{
		method: 'G\tET'
	}) {
		assert false
	}
	if _ := RequestObject.construct(RequestInput{ url: dom.URL{value: 'https://example.test/'} }, RequestInit{
		mode: .no_cors
		body: BodyInit{
			kind: .readable_stream
		}
		duplex: .half
	}) {
		assert false
	}
}

fn test_request_constructor_fallbacks_filtering_and_clone_body_independence() {
	object := RequestObject.construct(RequestInput{
		url: dom.URL{value: 'https://example.test/data'}
	}, RequestInit{})!
	assert object.mode() == .cors
	assert object.internal_request().unsafe_request
	assert object.internal_request().initiator_type? == .fetch
	with_headers := RequestObject.construct(RequestInput{
		url: dom.URL{value: 'https://example.test/data'}
	}, RequestInit{
		headers: [HeaderPair{ name: 'Cookie', value: 'secret' },
			HeaderPair{ name: 'X-Visible', value: 'yes' }]
	})!
	assert !with_headers.headers().has('Cookie')!
	assert with_headers.headers().get('X-Visible')? == 'yes'
	cross_origin_referrer := RequestObject.construct(RequestInput{
		url: dom.URL{value: 'https://example.test/data'}
	}, RequestInit{
		referrer: 'https://other.test/source'
	})!
	assert cross_origin_referrer.referrer() == 'about:client'
	with_body := RequestObject.construct(RequestInput{
		url: dom.URL{value: 'https://example.test/data'}
	}, RequestInit{
		method: 'POST'
		body: BodyInit{
			kind: .string_
			text: 'payload'
		}
	})!
	assert with_body.internal_request().body.body_object != none
	assert with_body.internal_request().body.bytes.len == 0
	clone := with_body.clone()!
	assert clone.internal_request().body.body_object != none
	assert clone.body_mixin().text()! == 'payload'
	assert !with_body.body_mixin().body_used()
}

fn test_request_constructor_copies_only_upstream_fields_and_uses_relevant_settings() {
	source := RequestObject.construct(RequestInput{
		url: dom.URL{value: 'https://input.test/data'}
	}, RequestInit{
		method: 'POST'
		body: BodyInit{ kind: .string_, text: 'payload' }
	})!
	mut source_request := source.request_
	source_request.service_workers_mode = .none
	source_request.destination = .script
	source_request.cryptographic_nonce_metadata = 'must-not-propagate'
	source_request.redirect_count = 7
	source_request.done = true
	client := &ConstructionTestClient{
		base_url: dom.URL{value: 'https://realm.test/base/'}
		origin_: dom.Origin{ value: 'https://realm.test' }
	}
	copy := RequestObject.construct(RequestInput{
		request: source
		environment: RequestClient(client)
	}, RequestInit{
		referrer: '../source'
		window_present: true
	})!
	request := copy.internal_request()
	assert request.method == 'POST'
	assert request.service_workers_mode == .all
	assert request.destination == none
	assert request.cryptographic_nonce_metadata == ''
	assert request.redirect_count == 0
	assert !request.done
	assert request.client != none
	assert request.traversable_for_user_prompts == .no_traversable
	assert copy.referrer() == 'https://realm.test/source'
	assert copy.body_mixin().text()! == 'payload'
}

fn test_response_object_constructor_factories_and_clone() {
	object := ResponseObject.construct(BodyInit{ kind: .string_, text: 'hello' }, ResponseInit{
		status: 201
		status_text: 'Created'
	})!
	assert object.status() == 201
	assert object.ok()
	assert object.headers().get('Content-Type')? == 'text/plain;charset=UTF-8'
	assert object.clone()!.status() == 201
	error_object := ResponseObject.error()
	assert error_object.type_() == .error
	redirect := ResponseObject.redirect('/next', 302, dom.URL{value: 'https://example.test/base'})!
	assert redirect.status() == 302
	assert redirect.headers().get('Location')? == 'https://example.test/next'
	json_value := infra.parse_json_string_to_javascript_value('{"ok":true}')!
	json_object := ResponseObject.json(json_value, ResponseInit{})!
	assert json_object.headers().get('Content-Type')? == 'application/json'
	assert json_object.body_mixin().text()! == '{"ok":true}'
}

fn test_response_wrappable_constructor_entry_points() {
	body := Body.from_bytes('direct'.bytes(), .bytes)
	direct := Response.create_with_body(ResponseInit{ status: 202 }, BodyWithType{
		body: body
		type_: 'text/custom'
	})!
	assert direct.status() == 202
	assert direct.headers().get('Content-Type')? == 'text/custom'
	assert direct.body_mixin().text()! == 'direct'

	constructed := Response.create_for_constructor(BodyInit{
		kind: .string_
		text: 'constructor'
	}, ResponseInit{})!
	assert constructed.body_mixin().text()! == 'constructor'
}

fn test_response_url_excludes_fragment() {
	mut response := Response.create()
	response.url_list = [dom.URL{value: 'https://example.test/path?q=1#fragment'}]
	object := &ResponseObject{
		response_: response
		headers_: Headers.from_header_list(response.header_list, .immutable)
	}
	assert object.url() == 'https://example.test/path?q=1'
}

fn test_response_rejects_status_text_and_null_body_status() {
	if _ := ResponseObject.construct(none, ResponseInit{ status: 199 }) {
		assert false
	}
	if _ := ResponseObject.construct(BodyInit{ kind: .string_, text: 'x' }, ResponseInit{
		status: 204
	}) {
		assert false
	}
}

fn test_response_status_text_accepts_obs_text_and_filtered_getters_delegate() {
	object := ResponseObject.construct(none, ResponseInit{ status_text: 'café' })!
	assert object.status_text() == 'café'
	mut internal := Response.create()
	internal.status = 201
	internal.url_list = [dom.URL{value: 'https://example.test/one'}]
	filtered := filtered_response(internal, .basic)
	filtered_object := &ResponseObject{
		response_: filtered
		headers_: Headers.from_header_list(filtered.header_list, .immutable)
	}
	internal.status = 202
	internal.url_list << dom.URL{value: 'https://example.test/two'}
	assert filtered_object.status() == 202
	assert filtered_object.redirected()
}

fn test_response_status_text_validates_http_octets() {
	text := [u8(9), 32, 33, 126, 128, 255].bytestr()
	response := ResponseObject.construct(none, ResponseInit{ status_text: text })!
	assert response.status_text().bytes() == text.bytes()
	for invalid in [u8(0), 10, 13, 31, 127] {
		if _ := ResponseObject.construct(none, ResponseInit{ status_text: [invalid].bytestr() }) {
			assert false, 'invalid status octet ${invalid}'
		}
	}
}
