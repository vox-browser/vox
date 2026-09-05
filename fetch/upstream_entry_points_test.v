@[has_globals]
module fetch

import dom
import http

struct CacheTestClient {
	top_level_origin dom.Origin
}

fn (client &CacheTestClient) fetch_request_client_api_base_url() dom.URL {
	return dom.URL{client.top_level_origin.serialize() + '/'}
}

fn (_ &CacheTestClient) fetch_request_client_is_window() bool {
	return false
}

fn (client &CacheTestClient) fetch_request_client_origin() dom.Origin {
	return client.top_level_origin
}

fn (_ &CacheTestClient) fetch_request_client_document_url() ?dom.URL {
	return none
}

fn (client &CacheTestClient) fetch_request_client_creation_url() dom.URL {
	return dom.URL{client.top_level_origin.value + '/'}
}

fn (_ &CacheTestClient) fetch_request_client_embedder_policy_credentialless() bool {
	return false
}

fn (client &CacheTestClient) fetch_request_client_top_level_origin() ?dom.Origin {
	return client.top_level_origin
}

fn (_ &CacheTestClient) fetch_request_client_top_level_creation_url() ?dom.URL {
	return none
}

fn (_ &CacheTestClient) fetch_request_client_cross_origin_isolated_capability() bool {
	return false
}

fn body_bytes_as_string(bytes []u8) !string {
	return bytes.bytestr()
}

fn test_upstream_request_accessors_and_pending_responses() {
	mut request := Request.create()
	request.set_method('POST')
	request.set_keepalive(true)
	request.set_credentials_mode(.include)
	request.set_url_list([dom.URL{'https://example.test/upload'}])
	assert request.fetch_request_method() == 'POST'
	assert request.fetch_request_keepalive()
	assert request.fetch_request_credentials_mode() == .include
	assert request.byte_serialize_origin() == 'null'.bytes()

	mut pending := PendingResponse.create(mut request, none)
	request.add_pending_response(pending)
	request.add_pending_response(pending)
	assert request.pending_responses.len == 1
	request.remove_pending_response(pending)
	assert request.pending_responses.len == 0
}

fn test_filtered_response_accessors_delegate_to_internal_response() {
	mut internal := Response.create()
	internal.status = 201
	internal.set_body_bytes('body'.bytes())
	internal.header_list.append(http.Header{ name: 'Content-Type', value: 'text/plain' })
	mut basic := Response.create_basic_filtered_response(internal)
	basic.set_status(202)
	basic.set_timing_allow_passed(true)
	assert internal.status == 202
	assert internal.timing_allow_passed
	assert basic.fetch_response_status() == 202
	assert basic.fetch_response_body()?.bytes() == 'body'.bytes()

	mut opaque := Response.create_opaque_filtered_response(internal)
	opaque.set_status(204)
	assert internal.status == 204
	assert opaque.fetch_response_status() == 0
	assert opaque.fetch_response_body() == none
	assert opaque.internal_response() == internal
}

fn test_fetch_timing_update_and_opaque_projection_match_upstream() {
	mut timing := FetchTimingInfo.create()
	timing.set_start_time(10)
	timing.update_final_timings(RequestTimingInfo{
		domain_lookup_start_microseconds: 1000
		domain_lookup_end_microseconds: 2000
		connect_start_microseconds: 3000
		connect_end_microseconds: 4000
		secure_connect_start_microseconds: 5000
		request_start_microseconds: 6000
		response_start_microseconds: 7000
		http_version_alpn_identifier: 'h2'
	}, true)
	connection := timing.fetch_timing_final_connection_timing_info()?
	assert connection.domain_lookup_start == 11
	assert connection.secure_connection_start == 15
	assert connection.alpn_negotiated_protocol == 'h2'
	assert timing.fetch_timing_final_network_request_start_time() == 16
	assert timing.fetch_timing_final_network_response_start_time() == 17

	opaque := create_opaque_timing_info(timing)
	assert opaque.start_time == 10
	assert opaque.post_redirect_start_time == 10
	assert opaque.end_time == 0
}

fn test_http_cache_partition_select_store_and_clear() {
	clear_http_memory_cache()
	set_http_memory_cache_enabled(true)
	mut request := Request.create()
	request.set_client(&CacheTestClient{
		top_level_origin: dom.Origin{ value: 'https://top-level.test' }
	})
	request.url_list = [dom.URL{'https://resource.test/data'}]
	mut response := Response.create()
	response.status = 203
	response.set_body_bytes('cached'.bytes())
	response.header_list.append(http.Header{ name: 'Cache-Control', value: 'max-age=60' })
	store_response_in_cache(request, response)
	assert select_response_from_cache(request) == none
	finalize_response_in_cache(request, response)
	cached := select_response_from_cache(request)?
	assert cached != response
	assert cached.status == 203
	assert cached.body?.bytes() == 'cached'.bytes()
	clear_http_memory_cache()
	assert select_response_from_cache(request) == none

	request.cache_mode = .no_store
	store_response_in_cache(request, response)
	assert select_response_from_cache(request) == none
}

fn test_body_entry_points_and_multipart_header_parser() {
	stream := Body.from_bytes('abc'.bytes(), .bytes)
	body := Body.create(stream.stream(), .bytes, 3)
	assert body.stream() == stream.stream()
	assert body.body_source() == .bytes
	assert body.body_length()? == 3
	assert byte_sequence_as_body('xyz'.bytes()).bytes() == 'xyz'.bytes()

	header := parse_multipart_form_data_header('Content-Disposition: form-data; name="line%0Abreak"; filename="a%22b.txt"\r\nContent-Type: text/plain\r\n')!
	assert header.name? == 'line\nbreak'
	assert header.filename? == 'a"b.txt'
	assert header.content_type? == 'text/plain'

	mixin := BodyMixin{
		body: Body.from_bytes('consume'.bytes(), .bytes)
	}
	assert consume_body(mixin, body_bytes_as_string)! == 'consume'
}

fn test_controller_holder_params_records_and_response_initialization() {
	mut controller := FetchController.create()
	mut holder := FetchControllerHolder.create()
	holder.set_controller(controller)
	assert holder.controller()? == controller

	request := Request.create()
	timing := FetchTimingInfo.create()
	mut params := FetchParams.create(request, timing)
	params.set_task_destination('fetch queue')
	params.set_cross_origin_isolated_capability(true)
	params.set_preloaded_response_candidate(PreloadedResponseCandidate{ kind: .pending })
	assert params.fetch_params_task_destination() == 'fetch queue'
	assert params.cross_origin_isolated_capability()
	assert params.fetch_params_preloaded_response_candidate().kind == .pending
	controller.set_fetch_params(params)
	controller.set_pending_request(request)

	mut record := FetchRecord.create(request, none)
	record.set_fetch_controller(controller)
	assert record.fetch_record_request() == request
	assert record.fetch_record_fetch_controller()? == controller

	response := Response.create()
	mut object := &ResponseObject{
		response_: response
		headers_: Headers.from_header_list(response.header_list, .none)
	}
	object.initialize_response(ResponseInit{
		status: 201
		status_text: 'Created'
		headers: [HeaderPair{ name: 'X-Test', value: 'yes' }]
	}, BodyWithType{
		body: Body.from_bytes('ok'.bytes(), .bytes)
		type_: 'text/plain'
	})!
	assert object.status() == 201
	assert object.status_text() == 'Created'
	assert object.headers().get('X-Test')? == 'yes'
	assert object.headers().get('Content-Type')? == 'text/plain'
}
