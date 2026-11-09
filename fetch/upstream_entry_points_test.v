@[has_globals]
module fetch

import dom
import http

struct CacheTestClient {
	top_level_origin dom.Origin
}

fn (client &CacheTestClient) fetch_request_client_api_base_url() dom.URL {
	return dom.URL{value: client.top_level_origin.serialize() + '/'}
}

fn (_ &CacheTestClient) fetch_request_client_policy_container() RequestPolicyContainer {
	return RequestPolicyContainer{}
}

fn (_ &CacheTestClient) fetch_request_client_is_window() bool {
	return false
}

fn (_ &CacheTestClient) fetch_request_client_is_top_level_window() bool {
	return false
}

fn (client &CacheTestClient) fetch_request_client_origin() dom.Origin {
	return client.top_level_origin
}

fn (_ &CacheTestClient) fetch_request_client_document_url() ?dom.URL {
	return none
}

fn (client &CacheTestClient) fetch_request_client_creation_url() dom.URL {
	return dom.URL{value: client.top_level_origin.value + '/'}
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
	request.set_url_list([dom.URL{value: 'https://example.test/upload'}])
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
	timing.set_post_redirect_start_time(10)
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
	request.url_list = [dom.URL{value: 'https://resource.test/data'}]
	request.header_list.append(http.Header{ name: 'Accept-Language', value: 'en' })
	mut response := Response.create()
	response.status = 203
	response.set_body_bytes('cached'.bytes())
	response.set_javascript_bytecode_cache([u8(1), 2, 3])
	response.set_javascript_bytecode_cache_vary_key(u64(17))
	response.header_list.append(http.Header{ name: 'Cache-Control', value: 'max-age=60' })
	store_response_in_cache(request, mut response)
	assert select_response_from_cache(request) == none
	finalize_response_in_cache(request, response)
	cached := select_response_from_cache(request)?
	assert cached != response
	assert cached.status == 203
	assert cached.body?.bytes() == 'cached'.bytes()
	assert cached.javascript_bytecode_cache()? == [u8(1), 2, 3]
	assert cached.javascript_bytecode_cache_vary_key()? == u64(17)
	assert cached.javascript_bytecode_cache_memory_cache_request_headers()?.get('Accept-Language')? == 'en'
	partition_key := determine_the_http_cache_partition(request)?
	update_javascript_bytecode_cache_in_http_memory_cache(partition_key, request.current_url(), request.method, request.header_list, 29, [
		u8(4),
		5,
		6,
	])
	updated := select_response_from_cache(request)?
	assert updated.javascript_bytecode_cache()? == [u8(4), 5, 6]
	assert updated.javascript_bytecode_cache_vary_key()? == u64(29)
	clear_http_memory_cache()
	store_response_in_cache(request, mut response)
	update_javascript_bytecode_cache_in_http_memory_cache(partition_key, request.current_url(), request.method, request.header_list, 31, [
		u8(7),
		8,
		9,
	])
	finalize_response_in_cache(request, response)
	pending_updated := select_response_from_cache(request)?
	assert pending_updated.javascript_bytecode_cache()? == [u8(7), 8, 9]
	assert pending_updated.javascript_bytecode_cache_vary_key()? == u64(31)
	clear_http_memory_cache()
	assert select_response_from_cache(request) == none

	request.cache_mode = .no_store
	store_response_in_cache(request, mut response)
	assert select_response_from_cache(request) == none
}

fn test_javascript_bytecode_cache_update_respects_vary_request_headers() {
	clear_http_memory_cache()
	set_http_memory_cache_enabled(true)
	client := &CacheTestClient{
		top_level_origin: dom.Origin{ value: 'https://top-level.test' }
	}
	mut english_request := Request.create()
	english_request.set_client(client)
	english_request.url_list = [dom.URL{value: 'https://resource.test/script.js'}]
	english_request.header_list.append(http.Header{ name: 'Accept-Language', value: 'en' })
	mut french_request := Request.create()
	french_request.set_client(client)
	french_request.url_list = english_request.url_list.clone()
	french_request.header_list.append(http.Header{ name: 'Accept-Language', value: 'fr' })

	mut english_response := Response.create()
	english_response.header_list.append(http.Header{ name: 'Cache-Control', value: 'max-age=60' })
	english_response.header_list.append(http.Header{ name: 'Vary', value: 'Accept-Language' })
	english_response.set_javascript_bytecode_cache([u8(1)])
	english_response.set_javascript_bytecode_cache_vary_key(u64(11))
	mut french_response := english_response.clone()
	french_response.set_javascript_bytecode_cache([u8(2)])
	french_response.set_javascript_bytecode_cache_vary_key(u64(12))
	store_response_in_cache(english_request, mut english_response)
	finalize_response_in_cache(english_request, english_response)
	store_response_in_cache(french_request, mut french_response)
	finalize_response_in_cache(french_request, french_response)

	partition_key := determine_the_http_cache_partition(english_request)?
	update_javascript_bytecode_cache_in_http_memory_cache(partition_key, english_request.current_url(), english_request.method, english_request.header_list, 99, [
		u8(9),
	])
	assert select_response_from_cache(english_request)?.javascript_bytecode_cache()? == [
		u8(9),
	]
	assert select_response_from_cache(english_request)?.javascript_bytecode_cache_vary_key()? == u64(99)
	assert select_response_from_cache(french_request)?.javascript_bytecode_cache()? == [
		u8(2),
	]
	assert select_response_from_cache(french_request)?.javascript_bytecode_cache_vary_key()? == u64(12)
	clear_http_memory_cache()
}

fn test_http_cache_reload_replaces_the_previous_body_and_no_store_bypasses_hits() {
	clear_http_memory_cache()
	defer { clear_http_memory_cache() }
	set_http_memory_cache_enabled(true)
	mut request := Request.create()
	request.set_client(&CacheTestClient{
		top_level_origin: dom.Origin{value: 'https://top-level.test'}
	})
	request.set_url(dom.URL{value: 'https://resource.test/reloaded'})
	mut first := Response.create()
	first.header_list.append(http.Header{name: 'Cache-Control', value: 'max-age=60'})
	first.set_body_bytes('before reload'.bytes())
	store_response_in_cache(request, mut first)
	finalize_response_in_cache(request, first)
	assert select_response_from_cache(request)?.body?.bytes() == 'before reload'.bytes()

	request.cache_mode = .no_store
	assert select_response_from_cache(request) == none
	request.cache_mode = .reload
	assert select_response_from_cache(request) == none
	mut replacement := Response.create()
	replacement.header_list.append(http.Header{name: 'Cache-Control', value: 'max-age=60'})
	replacement.set_body_bytes('after reload'.bytes())
	store_response_in_cache(request, mut replacement)
	finalize_response_in_cache(request, replacement)
	request.cache_mode = .default
	assert select_response_from_cache(request)?.body?.bytes() == 'after reload'.bytes()
}

fn test_fetched_data_receiver_prefers_cached_response_body_for_cache_finalization() {
	clear_http_memory_cache()
	set_http_memory_cache_enabled(true)
	mut request := Request.create()
	request.set_client(&CacheTestClient{
		top_level_origin: dom.Origin{ value: 'https://top-level.test' }
	})
	request.url_list = [dom.URL{value: 'https://resource.test/cached-body'}]
	mut response := Response.create()
	response.header_list.append(http.Header{ name: 'Cache-Control', value: 'max-age=60' })
	mut body := Body.streaming()
	response.set_body(body)
	store_response_in_cache(request, mut response)
	finalize_response_in_cache(request, response)
	assert select_response_from_cache(request) == none
	mut receiver := FetchedDataReceiver.create(FetchParams.create(request, FetchTimingInfo.create()), body.stream())
	receiver.set_response(response)
	receiver.set_body(body)
	receiver.set_cached_response_body('cache-owned'.bytes())
	receiver.handle_network_data(NetworkResponseData.from_file_backed_bytes('network-copy'.bytes()), .ongoing)
	// File-backed data can change the body's source to bytes before the network
	// has reported success. It still must not publish an incomplete entry.
	assert body.body_source() == .bytes
	finalize_response_in_cache(request, response)
	assert select_response_from_cache(request) == none
	receiver.handle_network_data(NetworkResponseData.from_bytes([]u8{}), .complete)
	receiver.stop_caching_incomplete_response()
	assert body.fully_read()! == 'network-copy'.bytes()
	assert select_response_from_cache(request)?.fetch_response_body_bytes()? == 'cache-owned'.bytes()
	clear_http_memory_cache()
}

fn test_http_cache_matches_out_of_order_completion_to_its_response() {
	clear_http_memory_cache()
	defer { clear_http_memory_cache() }
	set_http_memory_cache_enabled(true)
	mut request := Request.create()
	request.set_client(&CacheTestClient{
		top_level_origin: dom.Origin{value: 'https://top-level.test'}
	})
	request.set_url(dom.URL{value: 'https://resource.test/concurrent'})
	request.header_list.append(http.Header{name: 'Accept-Language', value: 'en'})
	mut first := Response.create()
	first.status = 203
	first.header_list.append(http.Header{name: 'Vary', value: 'Accept-Language'})
	first.header_list.append(http.Header{name: 'Cache-Control', value: 'max-age=60'})
	first.set_body_bytes('first response'.bytes())
	mut second := Response.create()
	second.header_list.append(http.Header{name: 'Vary', value: 'Accept-Language'})
	second.header_list.append(http.Header{name: 'Cache-Control', value: 'max-age=60, no-cache'})
	second.set_body_bytes('second response'.bytes())
	store_response_in_cache(request, mut first)
	store_response_in_cache(request, mut second)

	// Both producers have the same cache key and Vary selection. Completing
	// the second one first must retain its own no-cache metadata.
	finalize_response_in_cache(request, filtered_response(second, .basic))
	assert select_response_from_cache(request) == none
	finalize_response_in_cache(request, first)
	cached := select_response_from_cache(request)?
	assert cached.status == 203
	assert cached.fetch_response_body_bytes()? == 'first response'.bytes()
	// Repeated or late completion of the second producer cannot consume the
	// first producer's enrollment or overwrite its finished representation.
	finalize_response_in_cache(request, second)
	assert select_response_from_cache(request)?.fetch_response_body_bytes()? == 'first response'.bytes()
}

fn test_http_cache_clones_and_cleared_producers_cannot_finalize_other_entries() {
	clear_http_memory_cache()
	defer { clear_http_memory_cache() }
	set_http_memory_cache_enabled(true)
	mut request := Request.create()
	request.set_client(&CacheTestClient{
		top_level_origin: dom.Origin{value: 'https://top-level.test'}
	})
	request.set_url(dom.URL{value: 'https://resource.test/identity'})
	mut original := Response.create()
	original.header_list.append(http.Header{name: 'Cache-Control', value: 'max-age=60'})
	original.set_body_bytes('original'.bytes())
	store_response_in_cache(request, mut original)
	cloned := filtered_response(original, .basic).clone()
	finalize_response_in_cache(request, cloned)
	assert select_response_from_cache(request) == none

	clear_http_memory_cache()
	mut replacement := Response.create()
	replacement.header_list.append(http.Header{name: 'Cache-Control', value: 'max-age=60'})
	replacement.set_body_bytes('replacement'.bytes())
	store_response_in_cache(request, mut replacement)
	finalize_response_in_cache(request, original)
	assert select_response_from_cache(request) == none
	finalize_response_in_cache(request, replacement)
	assert select_response_from_cache(request)?.fetch_response_body_bytes()? == 'replacement'.bytes()
}

fn test_fetched_data_receiver_retires_incomplete_cache_enrollment() {
	clear_http_memory_cache()
	defer { clear_http_memory_cache() }
	set_http_memory_cache_enabled(true)
	mut request := Request.create()
	request.set_client(&CacheTestClient{
		top_level_origin: dom.Origin{value: 'https://top-level.test'}
	})
	request.set_url(dom.URL{value: 'https://resource.test/canceled'})
	for enrolled_before_stop in [true, false] {
		mut response := Response.create()
		response.header_list.append(http.Header{name: 'Cache-Control', value: 'max-age=60'})
		body := Body.streaming()
		response.set_body(body)
		mut receiver := FetchedDataReceiver.create(FetchParams.create(request, FetchTimingInfo.create()), body.stream())
		receiver.set_response(response)
		receiver.set_body(body)
		if enrolled_before_stop {
			store_response_in_cache(request, mut response)
		}
		receiver.set_cached_response_body('incomplete'.bytes())
		receiver.stop_caching_incomplete_response()
		// Transport teardown may precede the queued response callback. That late
		// callback must not enroll already-retired work.
		store_response_in_cache(request, mut response)
		response.set_body_bytes('late completion'.bytes())
		finalize_response_in_cache(request, response)
		assert select_response_from_cache(request) == none
		assert fetch_http_memory_cache_pending.len == 0
		assert receiver.cache_body_ == none
		assert receiver.cache_buffer_.len == 0
	}
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
