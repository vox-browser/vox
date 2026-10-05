@[has_globals]
module fetch

import dom
import fileapi
import http

__global (
	preload_host_calls             int
	transfer_pause_notifications   int
	receiver_pause_notifications   int
	receiver_resume_notifications  int
	redirect_transfer_releases     int
	redirect_request_stops         int
	navigation_redirect_host_calls int
)

fn controller_test_process_response(_ &Response) {}

fn preload_tracking_host(_ &Request) !&Response {
	preload_host_calls++
	return Response.create()
}

fn note_receiver_delivery_pause(paused bool) {
	if paused {
		receiver_pause_notifications++
	} else {
		receiver_resume_notifications++
	}
}

fn note_transfer_pause(paused bool) {
	if paused {
		transfer_pause_notifications++
	}
}

fn note_redirect_transfer_release() {
	redirect_transfer_releases++
}

fn note_redirect_request_stop() {
	redirect_request_stops++
}

fn transfer_lease_host(_ &Request) !&Response {
	mut response := Response.create()
	response.set_request_server_request(RequestServerRequest{
		set_body_delivery_paused: note_transfer_pause
	})
	return response
}

fn test_fetch_controller_params_tasks_and_timing() {
	mut controller := FetchController.create()
	assert controller.state() == .ongoing
	assert deserialize_serialized_abort_reason(controller) == 'AbortError'
	id := controller.next_fetch_task_id()
	controller.fetch_task_queued(id, 9)
	assert controller.ongoing_task_count() == 1
	controller.fetch_task_complete(id)
	assert controller.ongoing_task_count() == 0
	controller.abort('stop')
	assert controller.state() == .aborted
	assert deserialize_serialized_abort_reason(controller) == 'stop'
	assert controller.deserialize_a_serialized_abort_reason() == 'stop'
	mut request := Request.create()
	params := FetchParams.create(request, FetchTimingInfo.create())
	assert !params.is_canceled()
	assert controller.timing_info() == none
	assert params.controller.timing_info()? == params.timing_info
	opaque := create_opaque_timing_info(&FetchTimingInfo{
		start_time: 1
		redirect_start_time: 2
		end_time: 3
		render_blocking: true
	})
	assert opaque.start_time == 1
	assert opaque.post_redirect_start_time == 1
	assert opaque.redirect_start_time == 0
	assert opaque.end_time == 3
	assert opaque.render_blocking
}

fn test_fetch_controller_parks_and_resolves_pending_preloaded_response() {
	mut request := Request.create()
	request.url_list = [dom.URL{value: 'https://example.test/preloaded'}]
	mut params := FetchParams.create(request, FetchTimingInfo.create())
	params.set_preloaded_response_candidate(PreloadedResponseCandidate{ kind: .pending })
	preload_host_calls = 0
	first := main_fetch(params, FetchHost{ perform: preload_tracking_host })
	second := main_fetch(params, FetchHost{ perform: preload_tracking_host })
	assert first == second
	assert !first.is_resolved()
	assert params.controller.pending_preloaded_response()? == first
	assert preload_host_calls == 0

	mut preloaded := Response.create()
	preloaded.status = 203
	params.set_preloaded_response_candidate(PreloadedResponseCandidate{
		kind: .response
		response: preloaded
	})
	assert params.controller.pending_preloaded_response() == none
	assert first.response()?.status == 203
}

fn test_fetch_controller_tracks_started_font_network_request() {
	mut request := Request.create()
	request.url_list = [dom.URL{value: 'https://example.test/font.woff2'}]
	request.destination = .font
	request.cache_mode = .no_store
	params := FetchParams.create(request, FetchTimingInfo.create())
	assert !params.controller.has_started_request()
	assert !params.controller.requires_network()
	response := http_network_or_cache_fetch(params, FetchHost{
		perform: preload_tracking_host
	}).response()?
	assert !response.is_network_error()
	assert params.controller.has_started_request()
	assert params.controller.requires_network()
	assert params.controller.pending_request_ == none
}

fn test_fetch_params_and_fetch_propagate_response_body_transfer_lease() {
	mut request := Request.create()
	request.url_list = [dom.URL{value: 'https://example.test/leased'}]
	request.cache_mode = .no_store
	mut params := FetchParams.create(request, FetchTimingInfo.create())
	assert !params.has_response_body_transfer_lease()
	params.set_has_response_body_transfer_lease(true)
	assert params.copy().has_response_body_transfer_lease()
	transfer_pause_notifications = 0
	response := http_network_or_cache_fetch(params, FetchHost{
		perform: transfer_lease_host
	}).response()?
	assert !response.is_network_error()
	assert transfer_pause_notifications == 1

	mut blank_request := Request.create()
	blank_request.url_list = [dom.URL{value: 'about:blank'}]
	blank_request.origin = RequestOrigin{
		is_client: false
		origin: dom.Origin{ value: 'opaque' }
	}
	controller := fetch(blank_request, FetchAlgorithms.create(FetchAlgorithmsInput{}), FetchHost{
		perform: preload_tracking_host
	}, .yes)
	assert controller.fetch_params_?.has_response_body_transfer_lease()
}

fn test_image_fetch_accept_header_advertises_avif_and_webp() {
	mut request := Request.create()
	request.url_list = [dom.URL{value: 'about:blank'}]
	request.origin = RequestOrigin{
		is_client: false
		origin: dom.Origin{ value: 'opaque' }
	}
	request.destination = .image
	fetch(request, FetchAlgorithms.create(FetchAlgorithmsInput{}), FetchHost{
		perform: preload_tracking_host
	}, .no)
	assert request.header_list.get('Accept')? == 'image/avif,image/webp,image/png,image/svg+xml,image/*;q=0.8,*/*;q=0.5'
}

fn test_fetch_controller_matches_upstream_state_transitions_and_cleanup() {
	mut request := Request.create()
	mut params := FetchParams.create(request, FetchTimingInfo.create())
	params.algorithms = FetchAlgorithms.create(FetchAlgorithmsInput{
		process_response: controller_test_process_response
	})
	mut controller := params.controller
	controller.set_pending_request(request)
	id := controller.next_fetch_task_id()
	controller.fetch_task_queued(id, 17)
	controller.stop_fetch()
	assert controller.state() == .stopped
	assert !params.is_canceled()
	assert controller.ongoing_task_count() == 0
	assert controller.pending_request_stopped_
	if _ := params.algorithms.process_response() {
		assert false
	}

	mut canceled := FetchController.create()
	canceled.fetch_task_queued(canceled.next_fetch_task_id(), 23)
	canceled.abort('first')
	canceled.stop_fetch()
	assert canceled.state() == .aborted
	assert canceled.ongoing_task_count() == 1
	canceled.terminate()
	assert canceled.state() == .terminated
	canceled.abort('last')
	assert canceled.state() == .aborted
	assert canceled.deserialize_a_serialized_abort_reason() == 'last'

	mut live_controller := FetchController.create()
	mut record := FetchRecord.create(request, live_controller)
	record.finalize()
	assert live_controller.state() == .ongoing
}

fn test_pending_response_and_fetched_data_receiver() {
	mut request := Request.create()
	mut pending := PendingResponse.create(mut request, none)
	assert request.pending_responses.len == 1
	assert !pending.is_resolved()
	response := Response.create()
	pending.resolve(response)
	assert pending.is_resolved()
	assert request.pending_responses.len == 1
	pending.when_loaded(fn (_ &Response) {})
	assert request.pending_responses.len == 0
	mut body := Body.streaming()
	mut receiver := FetchedDataReceiver.create(FetchParams.create(request, FetchTimingInfo.create()), body.stream())
	receiver.handle_network_data(NetworkResponseData.from_bytes('abc'.bytes()), .ongoing)
	receiver.set_body(body)
	receiver.handle_network_data(NetworkResponseData.from_bytes([]u8{}), .complete)
	assert body.sniff_bytes_if_available()? == 'abc'.bytes()
	assert body.fully_read()! == 'abc'.bytes()
}

fn test_fetched_data_receiver_uses_file_backed_source_and_network_backpressure() {
	mut request := Request.create()
	request.cache_mode = .no_store
	mut body := Body.streaming()
	mut receiver := FetchedDataReceiver.create(FetchParams.create(request, FetchTimingInfo.create()), body.stream())
	receiver.set_body(body)
	receiver.handle_network_data(NetworkResponseData.from_file_backed_bytes('mapped'.bytes()), .ongoing)
	assert body.body_source() == .bytes
	assert body.body_length()? == 6
	assert body.bytes() == 'mapped'.bytes()

	receiver_pause_notifications = 0
	receiver_resume_notifications = 0
	receiver.set_network_request(RequestServerRequest{
		set_body_delivery_paused: note_receiver_delivery_pause
	})
	receiver.handle_network_data(NetworkResponseData.from_bytes([]u8{len: 5 * 1024 * 1024}), .ongoing)
	assert receiver_pause_notifications == 1
	assert receiver_resume_notifications == 1
	receiver.handle_network_data(NetworkResponseData.from_bytes([]u8{}), .complete)
	assert body.fully_read()!.len == 5 * 1024 * 1024 + 6
	assert body.stream().state() == .closed
}

fn test_abort_fetch_cancels_the_infrastructure_request_body_stream() {
	mut request := Request.create()
	body := Body.streaming()
	request.body = RequestBody{
		kind: .body_object
		body_object: body
	}
	abort_fetch(mut request, none, 'stop')
	assert body.disturbed()
	assert body.stream().state() == .closed
	assert request.body.body_object? == body

	mut response_object := ResponseObject.construct(BodyInit{
		kind: .readable_stream
	}, ResponseInit{})!
	response_body := response_object.response_.body?
	abort_fetch(mut request, response_object, 'response stopped')
	assert response_body.errored()
	assert response_body.error_reason() == 'response stopped'
	assert response_object.body_mixin().body? == response_body
}

fn test_cors_tao_and_fetch_metadata_headers() {
	mut request := Request.create()
	request.url_list = [dom.URL{value: 'https://example.test/a'}]
	request.origin = RequestOrigin{
		is_client: false
		origin: dom.Origin{ value: 'https://example.test' }
	}
	mut response := Response.create()
	response.header_list.append(http.Header{ name: 'Access-Control-Allow-Origin', value: '*' })
	assert cors_check(request, response)
	response.header_list.append(http.Header{
		name: 'Timing-Allow-Origin'
		value: 'https://example.test'
	})
	assert tao_check(request, response)
	request.destination = .image
	request.user_activation = true
	append_fetch_metadata_headers_for_request(mut request)
	assert request.header_list.get('Sec-Fetch-Dest')? == 'image'
	assert request.header_list.get('Sec-Fetch-Mode')? == 'no-cors'
}

fn host_fetch(request &Request) !&Response {
	mut response := Response.create()
	response.url_list = request.url_list.clone()
	response.status = 200
	response.set_body_bytes('ok'.bytes())
	return response
}

struct BlobFetchTestClient {
	creation_url     dom.URL
	origin           dom.Origin
	top_level_origin dom.Origin
	is_top_level     bool
}

struct BlobFetchTestEnvironment {
	creation_url dom.URL
}

fn (environment &BlobFetchTestEnvironment) fetch_request_environment_creation_url() dom.URL {
	return environment.creation_url
}

fn (_ &BlobFetchTestEnvironment) fetch_request_environment_top_level_origin() ?dom.Origin {
	return none
}

fn (_ &BlobFetchTestEnvironment) fetch_request_environment_top_level_creation_url() ?dom.URL {
	return none
}

fn (client &BlobFetchTestClient) fetch_request_client_api_base_url() dom.URL {
	return client.creation_url
}

fn (_ &BlobFetchTestClient) fetch_request_client_policy_container() RequestPolicyContainer {
	return RequestPolicyContainer{}
}

fn (_ &BlobFetchTestClient) fetch_request_client_is_window() bool {
	return true
}

fn (client &BlobFetchTestClient) fetch_request_client_is_top_level_window() bool {
	return client.is_top_level
}

fn (client &BlobFetchTestClient) fetch_request_client_origin() dom.Origin {
	return client.origin
}

fn (client &BlobFetchTestClient) fetch_request_client_document_url() ?dom.URL {
	return client.creation_url
}

fn (client &BlobFetchTestClient) fetch_request_client_creation_url() dom.URL {
	return client.creation_url
}

fn (_ &BlobFetchTestClient) fetch_request_client_embedder_policy_credentialless() bool {
	return false
}

fn (client &BlobFetchTestClient) fetch_request_client_top_level_origin() ?dom.Origin {
	return client.top_level_origin
}

fn (client &BlobFetchTestClient) fetch_request_client_top_level_creation_url() ?dom.URL {
	return client.creation_url
}

fn (_ &BlobFetchTestClient) fetch_request_client_cross_origin_isolated_capability() bool {
	return false
}

fn test_blob_scheme_fetch_authorizes_navigation_partition_and_top_level_self_fetch() {
	owner_origin := dom.Origin{ value: 'https://owner.test' }
	blob := fileapi.Blob.create('blob payload'.bytes(), 'text/plain')
	blob_url := fileapi.add_legacy_entry_to_blob_url_store(fileapi.BlobURLObject.from_blob(blob), fileapi.LegacyBlobURLEnvironment{
		id: 'blob-fetch-test'
		origin: owner_origin.serialize()
		storage_key: owner_origin.serialize_for_ipc()
	})!
	defer {
		fileapi.remove_legacy_entry_from_blob_url_store(blob_url)
	}
	host := FetchHost{ perform: host_fetch }

	mut navigation_request := Request.create()
	navigation_request.url_list = [dom.URL{value: blob_url}]
	navigation_request.destination = .document
	navigation_response := scheme_fetch(FetchParams.create(navigation_request, FetchTimingInfo.create()), host).response()?
	assert !navigation_response.is_network_error()
	assert navigation_response.body?.bytes() == 'blob payload'.bytes()
	assert navigation_response.header_list.get('Content-Length')? == '12'
	assert navigation_response.header_list.get('Content-Type')? == 'text/plain'

	mut reserved_environment_request := Request.create()
	reserved_environment_request.url_list = [dom.URL{value: blob_url}]
	reserved_environment_request.set_reserved_client(&BlobFetchTestEnvironment{
		creation_url: dom.URL{value: 'https://owner.test/environment'}
	})
	reserved_environment_response := scheme_fetch(FetchParams.create(reserved_environment_request, FetchTimingInfo.create()), host).response()?
	assert !reserved_environment_response.is_network_error()
	assert reserved_environment_response.body?.bytes() == 'blob payload'.bytes()

	mut partitioned_client_request := Request.create()
	partitioned_client_request.url_list = [dom.URL{value: blob_url}]
	partitioned_client_request.destination = .image
	partitioned_client_request.set_client(&BlobFetchTestClient{
		creation_url: dom.URL{value: 'https://owner.test/frame'}
		origin: owner_origin
		top_level_origin: dom.Origin{ value: 'https://top-level.test' }
	})
	partitioned_client_response := scheme_fetch(FetchParams.create(partitioned_client_request, FetchTimingInfo.create()), host).response()?
	assert !partitioned_client_response.is_network_error()

	mut range_request := Request.create()
	range_request.url_list = [dom.URL{value: blob_url}]
	range_request.destination = .document
	range_request.header_list.append(http.Header{ name: 'Range', value: 'bytes=5-' })
	range_response := scheme_fetch(FetchParams.create(range_request, FetchTimingInfo.create()), host).response()?
	assert range_response.status == 206
	assert range_response.range_requested
	assert range_response.body?.bytes() == 'payload'.bytes()
	assert range_response.header_list.get('Content-Range')? == 'bytes 5-11/12'

	foreign_origin := dom.Origin{ value: 'https://foreign.test' }
	mut nested_request := Request.create()
	nested_request.url_list = [dom.URL{value: blob_url}]
	nested_request.destination = .image
	nested_request.set_client(&BlobFetchTestClient{
		creation_url: dom.URL{value: 'https://foreign.test/frame'}
		origin: foreign_origin
		top_level_origin: foreign_origin
	})
	assert scheme_fetch(FetchParams.create(nested_request, FetchTimingInfo.create()), host).response()?.is_network_error()

	mut self_fetch_request := Request.create()
	self_fetch_request.url_list = [dom.URL{value: blob_url}]
	self_fetch_request.destination = .image
	self_fetch_request.set_client(&BlobFetchTestClient{
		creation_url: dom.URL{value: blob_url}
		origin: foreign_origin
		top_level_origin: foreign_origin
		is_top_level: true
	})
	self_fetch_response := scheme_fetch(FetchParams.create(self_fetch_request, FetchTimingInfo.create()), host).response()?
	assert !self_fetch_response.is_network_error()
	assert self_fetch_response.body?.bytes() == 'blob payload'.bytes()
}

fn cors_host_fetch(request &Request) !&Response {
	mut response := Response.create()
	response.url_list = request.url_list.clone()
	response.set_body_bytes('cross-origin'.bytes())
	response.header_list.append(http.Header{
		name: 'Access-Control-Allow-Origin'
		value: 'https://origin.test'
	})
	response.header_list.append(http.Header{
		name: 'Access-Control-Expose-Headers'
		value: 'X-Visible'
	})
	response.header_list.append(http.Header{ name: 'X-Visible', value: 'yes' })
	return response
}

fn no_cors_headers_host_fetch(request &Request) !&Response {
	mut response := Response.create()
	response.url_list = request.url_list.clone()
	response.set_body_bytes('hidden'.bytes())
	return response
}

fn test_scheme_and_main_fetch_host_boundary_and_data_url() {
	mut request := Request.create()
	request.url_list = [dom.URL{value: 'https://example.test/data'}]
	request.origin = RequestOrigin{
		is_client: false
		origin: dom.Origin{ value: 'https://example.test' }
	}
	host := FetchHost{
		perform: host_fetch
	}
	params := FetchParams.create(request, FetchTimingInfo.create())
	assert main_fetch(params, host).response()?.fetch_response_body()?.bytes() == 'ok'.bytes()
	mut data_request := Request.create()
	data_request.url_list = [dom.URL{value: 'data:text/plain,hello'}]
	data_params := FetchParams.create(data_request, FetchTimingInfo.create())
	assert scheme_fetch(data_params, host).response()?.body?.bytes() == 'hello'.bytes()
	set_http_memory_cache_enabled(false)
	assert !http_memory_cache_enabled()
	set_http_memory_cache_enabled(true)
}

fn test_main_fetch_applies_upstream_tainting_cors_and_integrity_steps() {
	host := FetchHost{ perform: cors_host_fetch }
	mut cors_request := Request.create()
	cors_request.url_list = [dom.URL{value: 'https://cross-origin.test/data'}]
	cors_request.origin = RequestOrigin{
		is_client: false
		origin: dom.Origin{ value: 'https://origin.test' }
	}
	cors_request.mode = .cors
	cors_response := main_fetch(FetchParams.create(cors_request, FetchTimingInfo.create()), host).response()?
	assert cors_response.response_type == .cors
	assert cors_response.fetch_response_body()?.bytes() == 'cross-origin'.bytes()
	assert cors_response.header_list.get('X-Visible')? == 'yes'

	mut opaque_request := Request.create()
	opaque_request.url_list = [dom.URL{value: 'https://cross-origin.test/data'}]
	opaque_request.origin = RequestOrigin{
		is_client: false
		origin: dom.Origin{ value: 'https://origin.test' }
	}
	opaque_response := main_fetch(FetchParams.create(opaque_request, FetchTimingInfo.create()), FetchHost{ perform: no_cors_headers_host_fetch }).response()?
	assert opaque_response.response_type == .opaque
	assert opaque_response.fetch_response_body() == none
	assert opaque_response.unsafe_response().body?.bytes() == 'hidden'.bytes()

	mut bad_cors_request := cors_request.clone()
	bad_cors_request.url_list = [dom.URL{value: 'https://cross-origin.test/bad'}]
	bad_cors_response := main_fetch(FetchParams.create(bad_cors_request, FetchTimingInfo.create()), FetchHost{ perform: no_cors_headers_host_fetch }).response()?
	assert bad_cors_response.is_network_error()

	mut integrity_request := Request.create()
	integrity_request.url_list = [dom.URL{value: 'https://origin.test/data'}]
	integrity_request.origin = RequestOrigin{
		is_client: false
		origin: dom.Origin{ value: 'https://origin.test' }
	}
	integrity_request.integrity_metadata = 'sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='
	integrity_response := main_fetch(FetchParams.create(integrity_request, FetchTimingInfo.create()), FetchHost{ perform: host_fetch }).response()?
	assert integrity_response.is_network_error()
}

fn test_network_partition_key_and_user_agent() {
	assert determine_the_network_partition_key(dom.Origin{ value: 'https://example.test' })?.top_level_origin.serialize() == 'https://example.test'
	opaque_a := dom.origin_create_opaque()
	opaque_b := dom.origin_create_opaque()
	assert determine_the_network_partition_key(opaque_a)?.top_level_origin.is_same_origin(opaque_a)
	assert determine_the_network_partition_key(opaque_a)?.top_level_origin.serialize_for_ipc() != determine_the_network_partition_key(opaque_b)?.top_level_origin.serialize_for_ipc()
	assert default_user_agent_value().contains('Ladybird')
}

fn redirect_host(request &Request) !&Response {
	mut response := Response.create()
	response.url_list = request.url_list.clone()
	response.set_body_bytes(request.current_url().serialize().bytes())
	return response
}

fn navigation_redirect_host(request &Request) !&Response {
	navigation_redirect_host_calls++
	mut response := Response.create()
	response.url_list = request.url_list.clone()
	if navigation_redirect_host_calls == 1 {
		response.status = 302
		response.header_list.append(http.Header{ name: 'Location', value: '/final' })
		response.header_list.append(http.Header{
			name: 'Timing-Allow-Origin'
			value: 'https://destination.test'
		})
	}
	return response
}

fn test_navigation_tao_check_and_redirect_chain_propagation() {
	destination_origin := dom.Origin{ value: 'https://destination.test' }
	mut response := Response.create()
	assert navigation_tao_check(response, destination_origin)
	response.set_navigation_timing_allow_values_list([['*'], ['https://destination.test']])
	assert navigation_tao_check(response, destination_origin)
	response.set_navigation_timing_allow_values_list([['*'], []string{}])
	assert !navigation_tao_check(response, destination_origin)

	mut request := Request.create()
	request.url_list = [dom.URL{value: 'https://origin.test/start'}]
	request.destination = .document
	request.mode = .navigate
	request.origin = RequestOrigin{
		is_client: false
		origin: dom.Origin{ value: 'https://origin.test' }
	}
	navigation_redirect_host_calls = 0
	result := main_fetch(FetchParams.create(request, FetchTimingInfo.create()), FetchHost{
		perform: navigation_redirect_host
	}).response()?
	assert navigation_redirect_host_calls == 2
	assert request.current_url().serialize() == 'https://origin.test/final'
	assert result.navigation_timing_allow_values_list() == [
		['https://destination.test'],
	]
	assert navigation_tao_check(result, destination_origin)
}

fn test_http_redirect_and_cors_preflight_boundaries() {
	mut request := Request.create()
	request.method = 'POST'
	request.url_list = [dom.URL{value: 'https://example.test/start'}]
	request.origin = RequestOrigin{
		is_client: false
		origin: dom.Origin{ value: 'https://example.test' }
	}
	mut redirect := Response.create()
	redirect.status = 303
	redirect.url_list = request.url_list.clone()
	redirect.header_list.append(http.Header{ name: 'Location', value: '/next' })
	redirect_transfer_releases = 0
	redirect_request_stops = 0
	redirect.set_request_server_request(RequestServerRequest{
		release_transfer_lease: note_redirect_transfer_release
		stop: note_redirect_request_stop
	})
	host := FetchHost{
		perform: redirect_host
	}
	params := FetchParams.create(request, FetchTimingInfo.create())
	result := http_redirect_fetch(params, redirect, host).response()?
	assert request.method == 'GET'
	assert request.current_url().serialize() == 'https://example.test/next'
	assert result.fetch_response_body()?.bytes().bytestr() == 'https://example.test/next'
	assert redirect_transfer_releases == 1
	assert redirect_request_stops == 1
}
