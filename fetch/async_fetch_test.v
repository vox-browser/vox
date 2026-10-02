module fetch

import dom
import http

@[heap]
struct DeferredFetchTransport {
mut:
	requests  []&Request
	responses []&PendingResponse
	finished  []&Response
}

fn deferred_fetch_host(transport &DeferredFetchTransport) FetchHost {
	return FetchHost{
		perform:       fn (_ &Request) !&Response {
			panic('The synchronous transport must not run')
		}
		perform_async: fn [transport] (request &Request) &PendingResponse {
			mut state := unsafe { &DeferredFetchTransport(transport) }
			mut mutable_request := unsafe { &Request(request) }
			pending := PendingResponse.create(mut mutable_request, none)
			state.requests << request
			state.responses << pending
			return pending
		}
	}
}

fn finish_deferred_transport(transport &DeferredFetchTransport, index int, status u16, headers []http.Header, body string) {
	request := transport.requests[index]
	mut response := Response.create()
	response.status = status
	response.url_list = request.url_list.clone()
	for header in headers { response.header_list.append(header) }
	response.set_body_bytes(body.bytes())
	mut pending := unsafe { &PendingResponse(transport.responses[index]) }
	pending.resolve(response)
}

fn test_main_fetch_keeps_a_genuine_pending_network_response_until_transport_completion() {
	state := &DeferredFetchTransport{}
	host := deferred_fetch_host(state)
	mut request := Request.create()
	request.url_list = [dom.URL{'https://example.test/deferred'}]
	request.origin = RequestOrigin{ is_client: false, origin: request.current_url().origin() }
	request.mode = .same_origin
	request.cache_mode = .no_store
	mut pending := main_fetch(FetchParams.create(request, FetchTimingInfo.create()), &host)
	assert !pending.is_resolved()
	assert state.requests.len == 1
	pending.when_loaded(fn [state] (response &Response) {
		mut transport := unsafe { &DeferredFetchTransport(state) }
		transport.finished << response
	})
	assert state.finished.len == 0
	finish_deferred_transport(state, 0, 200, [], 'deferred bytes')
	assert pending.is_resolved()
	assert state.finished.len == 1
	assert !state.finished[0].is_network_error()
	assert state.finished[0].unsafe_response().body?.bytes() == 'deferred bytes'.bytes()
}

fn test_async_redirects_preserve_pending_state_across_both_network_requests() {
	state := &DeferredFetchTransport{}
	host := deferred_fetch_host(state)
	mut request := Request.create()
	request.url_list = [dom.URL{'https://example.test/start'}]
	request.origin = RequestOrigin{ is_client: false, origin: request.current_url().origin() }
	request.mode = .same_origin
	request.method = 'POST'
	request.body = RequestBody{ kind: .bytes, bytes: 'posted'.bytes() }
	request.header_list.append(http.Header{ name: 'Content-Type', value: 'text/plain' })
	request.cache_mode = .no_store
	pending := main_fetch(FetchParams.create(request, FetchTimingInfo.create()), &host)
	finish_deferred_transport(state, 0, 302, [http.Header{ name: 'Location', value: '/end' }], '')
	assert state.requests.len == 2
	assert !pending.is_resolved()
	assert state.requests[1].method == 'GET'
	assert state.requests[1].body.kind == .empty
	assert !state.requests[1].header_list.contains('Content-Type')
	finish_deferred_transport(state, 1, 200, [], 'redirected bytes')
	assert pending.response()?.url()?.serialize() == 'https://example.test/end'
	assert pending.response()?.unsafe_response().body?.bytes() == 'redirected bytes'.bytes()
	assert request.redirect_count == 1
}

fn test_async_cors_preflight_waits_before_starting_the_actual_request_and_validates_the_response() {
	mut cache := PreflightCache.the()
	cache.entries.clear()
	state := &DeferredFetchTransport{}
	host := deferred_fetch_host(state)
	mut request := Request.create()
	request.url_list = [dom.URL{'https://cross-origin.test/put'}]
	request.origin = RequestOrigin{ is_client: false, origin: dom.URL{'https://origin.test/'}.origin() }
	request.mode = .cors
	request.method = 'PUT'
	request.use_cors_preflight = true
	request.unsafe_request = true
	request.credentials_mode = .omit
	request.cache_mode = .no_store
	pending := main_fetch(FetchParams.create(request, FetchTimingInfo.create()), &host)
	assert state.requests.len == 1
	assert state.requests[0].method == 'OPTIONS'
	assert !pending.is_resolved()
	finish_deferred_transport(state, 0, 204, [
		http.Header{ name: 'Access-Control-Allow-Origin', value: 'https://origin.test' },
		http.Header{ name: 'Access-Control-Allow-Methods', value: 'PUT' },
	], '')
	assert state.requests.len == 2
	assert state.requests[1].method == 'PUT'
	assert !pending.is_resolved()
	finish_deferred_transport(state, 1, 200, [http.Header{ name: 'Access-Control-Allow-Origin', value: 'https://origin.test' }], 'allowed')
	assert pending.response()?.response_type == .cors
	assert pending.response()?.unsafe_response().body?.bytes() == 'allowed'.bytes()
}

fn test_async_fetch_handover_runs_when_the_response_arrives_and_termination_discards_late_success() {
	state := &DeferredFetchTransport{}
	host := deferred_fetch_host(state)
	mut request := Request.create()
	request.url_list = [dom.URL{'https://example.test/controller'}]
	request.origin = RequestOrigin{ is_client: false, origin: request.current_url().origin() }
	request.mode = .same_origin
	request.cache_mode = .no_store
	algorithms := FetchAlgorithms.create(FetchAlgorithmsInput{
		process_response: fn [state] (response &Response) {
			mut transport := unsafe { &DeferredFetchTransport(state) }
			transport.finished << response
		}
	})
	mut controller := fetch(request, algorithms, &host, .no)
	assert !request.done
	assert state.finished.len == 0
	controller.terminate()
	finish_deferred_transport(state, 0, 200, [], 'late success')
	assert request.done
	assert state.finished.len == 1
	assert state.finished[0].is_network_error()
}
