@[has_globals]
module fetch

import dom
import http

fn test_fetch_controller_params_tasks_and_timing() {
	mut controller := FetchController.create()
	assert controller.state() == .ongoing
	id := controller.next_fetch_task_id()
	controller.fetch_task_queued(id, 9)
	assert controller.ongoing_task_count() == 1
	controller.fetch_task_complete(id)
	assert controller.ongoing_task_count() == 0
	controller.abort('stop')
	assert controller.state() == .aborted
	assert controller.deserialize_a_serialized_abort_reason() == 'stop'
	request := Request.create()
	params := FetchParams.create(request, FetchTimingInfo.create())
	assert !params.is_canceled()
	opaque := create_opaque_timing_info(&FetchTimingInfo{
		start_time:          1
		redirect_start_time: 2
		end_time:            3
	})
	assert opaque.start_time == 1 && opaque.redirect_start_time == 0 && opaque.end_time == 3
}

fn test_pending_response_and_fetched_data_receiver() {
	request := Request.create()
	mut pending := PendingResponse.create(request, none)
	assert !pending.is_resolved()
	response := Response.create()
	pending.resolve(response)
	assert pending.is_resolved()
	mut receiver :=
		FetchedDataReceiver.create(FetchParams.create(request, FetchTimingInfo.create()))
	mut body := Body.streaming()
	receiver.set_body(body)
	receiver.handle_network_bytes('abc'.bytes(), .complete)
	assert receiver.copy_unpulled_bytes() == 'abc'.bytes()
	receiver.set_pending_pull()
	assert receiver.lifecycle_state() == .closed
	assert body.sniff_bytes_if_available()? == 'abc'.bytes()
}

fn test_cors_tao_and_fetch_metadata_headers() {
	mut request := Request.create()
	request.url_list = [dom.URL{'https://example.test/a'}]
	request.origin = RequestOrigin{
		is_client: false
		origin:    dom.Origin{'https://example.test'}
	}
	mut response := Response.create()
	response.header_list.append(http.Header{ name: 'Access-Control-Allow-Origin', value: '*' })
	assert cors_check(request, response)
	response.header_list.append(http.Header{
		name:  'Timing-Allow-Origin'
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
	response.body = 'ok'.bytes()
	return response
}

fn test_scheme_and_main_fetch_host_boundary_and_data_url() {
	mut request := Request.create()
	request.url_list = [dom.URL{'https://example.test/data'}]
	host := FetchHost{
		perform: host_fetch
	}
	params := FetchParams.create(request, FetchTimingInfo.create())
	assert main_fetch(params, host).response()?.body? == 'ok'.bytes()
	mut data_request := Request.create()
	data_request.url_list = [dom.URL{'data:text/plain,hello'}]
	data_params := FetchParams.create(data_request, FetchTimingInfo.create())
	assert scheme_fetch(data_params, host).response()?.body? == 'hello'.bytes()
	set_http_memory_cache_enabled(false)
	assert !http_memory_cache_enabled()
	set_http_memory_cache_enabled(true)
}

fn test_network_partition_key_and_user_agent() {
	assert determine_the_network_partition_key(dom.Origin{'https://example.test'})?.top_level_origin == 'https://example.test'
	assert determine_the_network_partition_key(dom.Origin{'opaque'}) == none
	assert default_user_agent_value().contains('Ladybird')
}

fn redirect_host(request &Request) !&Response {
	mut response := Response.create()
	response.url_list = request.url_list.clone()
	response.body = request.current_url().serialize().bytes()
	return response
}

fn test_http_redirect_and_cors_preflight_boundaries() {
	mut request := Request.create()
	request.method = 'POST'
	request.url_list = [dom.URL{'https://example.test/start'}]
	request.origin = RequestOrigin{
		is_client: false
		origin:    dom.Origin{'https://example.test'}
	}
	mut redirect := Response.create()
	redirect.status = 303
	redirect.url_list = request.url_list.clone()
	redirect.header_list.append(http.Header{ name: 'Location', value: '/next' })
	host := FetchHost{
		perform: redirect_host
	}
	params := FetchParams.create(request, FetchTimingInfo.create())
	result := http_redirect_fetch(params, redirect, host).response()?
	assert request.method == 'GET'
	assert request.current_url().serialize() == 'https://example.test/next'
	assert result.body?.bytestr() == 'https://example.test/next'
}
