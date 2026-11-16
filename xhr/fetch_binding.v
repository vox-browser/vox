// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// XMLHttpRequest.cpp: send's Fetch request, async response and timeout algorithms.
module xhr

import dom
import fetch
import html
import http
import highresolutiontime
import platform
import url as liburl

pub fn XMLHttpRequest.construct_in_settings(settings &html.EnvironmentSettingsObject, host &fetch.FetchHost) &XMLHttpRequest {
	global := &XMLHttpRequestGlobal{
		kind: if settings.fetch_request_client_is_window() { GlobalKind.window } else { GlobalKind.worker }
		base_url: settings.api_base_url().serialize()
		origin: settings.origin()
		associated_document: settings.responsible_document()
		fetch_client: fetch.RequestClient(settings)
		fetch_host: host
		event_timestamp: fn [settings] () f64 {
			return highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
				time_origin: settings.time_origin()
				cross_origin_isolated_capability: settings.fetch_request_client_cross_origin_isolated_capability()
			})
		}
	}
	return XMLHttpRequest.create(global)
}

fn (request &XMLHttpRequest) create_fetch_request() &fetch.Request {
	mut result := fetch.Request.create()
	result.method = request.request_method
	result.url_list = [dom.URL{value: request.request_url}]
	for header in request.author_request_headers {
		result.header_list.append(http.Header{ name: header.name, value: header.value })
	}
	result.unsafe_request = true
	if request.request_body_present {
		result.body = fetch.RequestBody{
			kind: .body_object
			body_object: fetch.Body.from_bytes(request.request_body, .bytes)
		}
	}
	result.client = request.global_object_.fetch_client
	result.mode = .cors
	result.use_cors_preflight = request.upload_listener
	result.credentials_mode = if request.with_credentials_ { .include } else { .same_origin }
	parsed := liburl.parse(request.request_url) or { panic('XHR request URL was not parsed by open()') }
	result.use_url_credentials = parsed.includes_credentials()
	result.initiator_type = .xml_http_request
	return result
}

fn (mut request XMLHttpRequest) start_async_fetch_if_bound() ! {
	host := request.global_object_.fetch_host or { return }
	_ := request.global_object_.fetch_client or { return error('XMLHttpRequest Fetch binding requires its relevant settings object') }
	fetch_request := request.create_fetch_request()
	request.fetch_request_ = fetch_request
	algorithms := fetch.FetchAlgorithms.create(fetch.FetchAlgorithmsInput{
		process_request_body_chunk_length: fn [mut request, fetch_request] (length u64) {
			if !request.is_active_fetch_request(fetch_request) { return }
			request.receive_upload_chunk_length(length)
		}
		process_request_end_of_body: fn [mut request, fetch_request] () {
			if !request.is_active_fetch_request(fetch_request) { return }
			request.complete_upload()
		}
		process_response: fn [mut request, fetch_request] (response &fetch.Response) {
			if !request.is_active_fetch_request(fetch_request) { return }
			request.receive_fetch_response(fetch_request, response)
		}
	})
	request.async_request_ = none
	send_start_time := xhr_monotonic_now()
	mut controller := fetch.fetch(fetch_request, algorithms, host, .no)
	// A host may deliver callbacks synchronously. Do not overwrite a controller
	// installed by reentrant open()/send(), or arm a completed request's timer.
	current_request := request.fetch_request_ or {
		controller.terminate()
		return
	}
	if voidptr(current_request) != voidptr(fetch_request) {
		controller.terminate()
		return
	}
	request.fetch_controller_ = controller
	if !request.send_flag {
		if !fetch_request.done { controller.terminate() }
		return
	}
	request.async_send_start_time_ = send_start_time
	request.async_request_ = fetch_request
	request.restart_timeout_timer()
}

fn (request &XMLHttpRequest) is_active_fetch_request(fetch_request &fetch.Request) bool {
	current_request := request.fetch_request_ or { return false }
	return request.send_flag && voidptr(current_request) == voidptr(fetch_request)
}

fn (mut request XMLHttpRequest) restart_timeout_timer() {
	request.stop_timeout_timer()
	if !request.send_flag || request.synchronous || request.timeout_ms == 0 { return }
	fetch_request := request.async_request_ or { return }
	if fetch_request.done { return }
	// Changing timeout keeps its deadline relative to the original send().
	// An already elapsed deadline is scheduled without a new timeout period.
	elapsed_ms := (xhr_monotonic_now() - request.async_send_start_time_) / 1_000_000
	timeout_ms := i64(request.timeout_ms)
	remaining_ms := if elapsed_ms < timeout_ms { timeout_ms - elapsed_ms } else { i64(0) }
	fetch_controller := request.fetch_controller_
	mut timer := platform.Timer.create_single_shot(int(remaining_ms), fn [mut request, fetch_request, fetch_controller] () {
		active_request := request.async_request_ or { return }
		if voidptr(active_request) != voidptr(fetch_request)
			|| voidptr(request.fetch_controller_) != voidptr(fetch_controller) { return }
		// Clear ownership before error events can start another request.
		request.stop_timeout_timer()
		request.async_request_ = none
		if !fetch_request.done {
			request.timed_out = true
			mut controller := fetch_controller
			controller.terminate()
			request.handle_errors() or { panic(err) }
		}
	})
	request.timeout_timer_ = timer
	request.timeout_timer_active = true
	timer.start()
}

@[heap]
struct SynchronousFetchState {
mut:
	processed_response bool
	did_time_out bool
}

// XMLHttpRequest.cpp: send, synchronous branch. The host still performs the
// network operation asynchronously; response consumption uses a parallel
// queue while send pauses in the main HTML loop, as in upstream.
fn (mut request XMLHttpRequest) start_synchronous_fetch_if_bound() ! {
	host := request.global_object_.fetch_host or { return }
	_ := request.global_object_.fetch_client or {
		return error('XMLHttpRequest Fetch binding requires its relevant settings object')
	}
	fetch_request := request.create_fetch_request()
	request.fetch_request_ = fetch_request
	state := &SynchronousFetchState{}
	algorithms := fetch.FetchAlgorithms.create(fetch.FetchAlgorithmsInput{
		process_response_consume_body: fn [mut request, state] (response &fetch.Response, result fetch.BodyBytes) {
			if state.did_time_out { return }
			if result.kind != .failure {
				request.fetch_response_ = response
				request.response_ = project_fetch_response(response)
			}
			if result.kind == .bytes { request.received_bytes << result.bytes }
			mut observation := unsafe { &SynchronousFetchState(state) }
			observation.processed_response = true
		}
	})
	request.fetch_controller_ = fetch.fetch_with_parallel_queue(fetch_request, algorithms, host, .yes, .no)
	if request.timeout_ms != 0 {
		request.stop_timeout_timer()
		mut timer := platform.Timer.create_single_shot(int(request.timeout_ms), fn [mut request, state] () {
			mut observation := unsafe { &SynchronousFetchState(state) }
			observation.did_time_out = true
			request.stop_timeout_timer()
		})
		request.timeout_timer_ = timer
		request.timeout_timer_active = true
		timer.start()
	}
	// Preserve upstream's FIXME: this pause permits ordinary HTML tasks too.
	mut event_loop := html.main_thread_event_loop()
	event_loop.spin_until(fn [state] () bool {
		return state.processed_response || state.did_time_out
	})
	request.stop_timeout_timer()
	if !state.processed_response {
		request.timed_out = true
		request.fetch_controller_.terminate()
	}
	if !request.timed_out || request.fetch_controller_.has_report_timing_steps() {
		request.fetch_controller_.report_timing()
	}
	request.handle_response_end_of_body()!
}

fn project_fetch_response(response &fetch.Response) MockResponse {
	return MockResponse{
		url: if final_url := response.url() { final_url.serialize() } else { '' }
		status: response.status
		status_text: response.status_message
		headers: response.header_list.headers().map(ResponseHeader{ name: it.name, value: it.value })
		network_error: response.network_error_message
		aborted: response.aborted
		body_is_null: response.fetch_response_body() == none
	}
}

fn (request &XMLHttpRequest) queue_body_read_task(algorithm fn ()) {
	client := request.global_object_.fetch_client or { panic('XHR body reading requires its relevant settings object') }
	if client is fetch.FetchTaskDestinationProvider {
		client.fetch_request_client_queue_fetch_task(algorithm)
		return
	}
	panic('XHR relevant global object does not provide its networking task destination')
}

fn (mut request XMLHttpRequest) receive_fetch_response(fetch_request &fetch.Request, response &fetch.Response) {
	request.fetch_response_ = response
	request.receive_headers(project_fetch_response(response)) or { return }
	if !request.is_active_fetch_request(fetch_request)
		|| request.response_.network_error != none || request.state != .headers_received { return }
	if mut body := response.fetch_response_body() {
		body.incrementally_read(fn [mut request, fetch_request] (bytes []u8) {
			request.queue_body_read_task(fn [mut request, fetch_request, bytes] () {
				if !request.is_active_fetch_request(fetch_request) { return }
				request.receive_chunk(bytes)
			})
		}, fn [mut request, fetch_request] () {
			request.queue_body_read_task(fn [mut request, fetch_request] () {
				if !request.is_active_fetch_request(fetch_request) { return }
				request.handle_response_end_of_body() or { panic(err) }
			})
		}, fn [mut request, fetch_request] (_ string) {
			request.queue_body_read_task(fn [mut request, fetch_request] () {
				if !request.is_active_fetch_request(fetch_request) { return }
				error_response := fetch.Response.network_error('A network error occurred processing body.')
				request.fetch_response_ = error_response
				request.response_ = project_fetch_response(error_response)
				request.handle_errors() or { panic(err) }
			})
		})
	} else {
		request.handle_response_end_of_body() or { panic(err) }
	}
}
