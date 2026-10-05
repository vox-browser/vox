module xhr

import dom
import fetch
import html
import http
import platform
import streams
import time

@[heap]
struct XHRTransportObservation {
mut:
	requests []&fetch.Request
	pending []&fetch.PendingResponse
}

fn xhr_deferred_host(state &XHRTransportObservation) &fetch.FetchHost {
	return &fetch.FetchHost{
		perform: fn (_ &fetch.Request) !&fetch.Response { panic('blocking XHR transport was used') }
		perform_async: fn [state] (request &fetch.Request) &fetch.PendingResponse {
			mut observation := unsafe { &XHRTransportObservation(state) }
			mut mutable_request := unsafe { &fetch.Request(request) }
			pending := fetch.PendingResponse.create(mut mutable_request, none)
			observation.requests << request
			observation.pending << pending
			return pending
		}
	}
}

fn xhr_settings() (&html.EnvironmentSettingsObject, &html.EventLoop) {
	mut document := dom.Document.create(dom.URL{value: 'https://example.test/xhr-owner'})
	document.set_origin(document.url.origin())
	window := html.WindowModel.create_top_level(document, none, 'xhr-owner') or { panic(err) }
	mut realm := &html.ScriptingRealm{}
	object := html.WindowEnvironmentSettingsObject.setup(window, document.url, mut realm, none, document.url, document.origin())
	return object.settings, object.settings.responsible_event_loop()
}

fn xhr_run_queued_work(owner &html.EventLoop) {
	mut queue := owner.task_queue()
	for i := 0; i < 100; i++ {
		mut task := queue.take_first_runnable() or { return }
		task.execute()
	}
	panic('XHR queue did not settle')
}

fn xhr_resolve_transport(state &XHRTransportObservation, index int, response &fetch.Response) {
	mut pending := state.pending[index]
	pending.resolve(response)
}

fn xhr_transport_response(request &fetch.Request, body ?&fetch.Body) &fetch.Response {
	mut response := fetch.Response.create()
	response.status = 200
	response.status_message = 'OK'
	response.url_list = request.url_list.clone()
	response.header_list.append(http.Header{ name: 'Content-Type', value: 'text/plain;charset=UTF-8' })
	response.header_list.append(http.Header{ name: 'Set-Cookie', value: 'hidden=secret' })
	response.body = body
	return response
}

fn test_async_send_constructs_the_source_request_and_waits_for_fetch_and_future_body_bytes() {
	settings, owner := xhr_settings()
	state := &XHRTransportObservation{}
	host := xhr_deferred_host(state)
	mut request := XMLHttpRequest.construct_in_settings(settings, host)
	request.open('POST', '/xhr-stream?credentials', true, 'alex', 'pass')!
	request.set_with_credentials(true)!
	request.set_request_header('X-Author', 'request-header')!
	request.upload_object.listeners['progress'] = true
	request.send_text('posted bytes')!
	assert request.state == .opened
	assert state.requests.len == 1
	actual := request.fetch_request_ or { panic('no Fetch request') }
	assert actual.method == 'POST'
	assert actual.current_url().serialize() == 'https://alex:pass@example.test/xhr-stream?credentials'
	assert actual.header_list.get('X-Author')? == 'request-header'
	assert actual.unsafe_request
	assert actual.body.kind == .body_object
	assert actual.body.body_object?.bytes() == 'posted bytes'.bytes()
	assert actual.client?.fetch_request_client_origin().is_same_origin(settings.origin())
	assert actual.mode == .cors
	assert actual.use_cors_preflight
	assert actual.credentials_mode == .include
	assert actual.use_url_credentials
	assert actual.initiator_type? == .xml_http_request
	assert !actual.done
	body := fetch.Body.streaming()
	mut producer := body.stream()
	response := xhr_transport_response(state.requests[0], body)
	xhr_resolve_transport(state, 0, response)
	assert request.state == .opened
	xhr_run_queued_work(owner)
	assert request.state == .headers_received
	assert request.status() == 200
	assert request.get_response_header('Set-Cookie') == none
	assert !actual.done
	producer.enqueue(streams.bytes_value('first'.bytes()))!
	assert request.received_bytes.len == 0
	xhr_run_queued_work(owner)
	assert request.state == .loading
	assert request.response_text()! == 'first'
	producer.enqueue(streams.bytes_value('second'.bytes()))!
	xhr_run_queued_work(owner)
	assert request.received_bytes == 'firstsecond'.bytes()
	assert !actual.done
	producer.close()
	assert request.state == .loading
	xhr_run_queued_work(owner)
	assert request.state == .done
	assert !request.send_flag
	assert request.response_text()! == 'firstsecond'
	assert actual.done
	assert request.events.last().type_ == 'loadend'
	assert !request.upload_complete // Response EOF does not invent an upload completion.
}

fn test_async_send_processes_null_bodies_and_network_errors_through_fetch() {
	settings, owner := xhr_settings()
	state := &XHRTransportObservation{}
	host := xhr_deferred_host(state)
	mut request := XMLHttpRequest.construct_in_settings(settings, host)
	request.open('GET', '/xhr-null', true, none, none)!
	request.send()!
	xhr_resolve_transport(state, 0, xhr_transport_response(state.requests[0], none))
	xhr_run_queued_work(owner)
	assert request.state == .done
	assert request.received_bytes.len == 0
	assert request.events.last().type_ == 'loadend'
	request.open('GET', '/xhr-error', true, none, none)!
	request.send()!
	xhr_resolve_transport(state, 1, fetch.Response.network_error('socket failed'))
	xhr_run_queued_work(owner)
	assert request.state == .done
	assert request.status() == 0
	assert request.events[request.events.len - 2].type_ == 'error'
	assert request.fetch_controller_.state() == .ongoing
}

fn test_native_timeout_terminates_fetch_while_response_body_is_still_pending() {
	if !platform.native_timer_scheduling_available() { return }
	settings, owner := xhr_settings()
	state := &XHRTransportObservation{}
	host := xhr_deferred_host(state)
	mut request := XMLHttpRequest.construct_in_settings(settings, host)
	request.open('GET', '/xhr-timeout', true, none, none)!
	request.set_timeout(20)!
	request.send()!
	body := fetch.Body.streaming()
	mut producer := body.stream()
	xhr_resolve_transport(state, 0, xhr_transport_response(state.requests[0], body))
	xhr_run_queued_work(owner)
	assert request.state == .headers_received
	assert !request.fetch_request_?.done
	deadline := time.sys_mono_now() + i64(2_000_000_000)
	for request.state != .done && time.sys_mono_now() < deadline { platform.pump_native_events(0.05) }
	assert request.state == .done
	assert request.timed_out
	assert request.fetch_controller_.state() == .terminated
	assert request.events[request.events.len - 2].type_ == 'timeout'
	assert !request.timeout_timer_active
	producer.enqueue(streams.bytes_value('late'.bytes()))!
	producer.close()
	xhr_run_queued_work(owner)
	assert request.received_bytes.len == 0
	assert request.events.last().type_ == 'loadend'
	assert request.status() == 0
}

fn test_open_and_abort_change_the_real_fetch_controller_state() {
	settings, owner := xhr_settings()
	state := &XHRTransportObservation{}
	host := xhr_deferred_host(state)
	mut request := XMLHttpRequest.construct_in_settings(settings, host)
	request.open('GET', '/xhr-abort', true, none, none)!
	request.send()!
	first := request.fetch_controller_
	request.abort()
	assert first.state() == .aborted
	assert request.state == .unsent
	xhr_resolve_transport(state, 0, xhr_transport_response(state.requests[0], none))
	xhr_run_queued_work(owner)
	assert request.state == .unsent
	request.open('GET', '/xhr-reopen', true, none, none)!
	request.send()!
	second := request.fetch_controller_
	request.open('GET', '/xhr-new', true, none, none)!
	assert second.state() == .terminated
	assert request.state == .opened
	assert !request.send_flag
}

fn test_reentrant_loadstart_abort_prevents_the_real_fetch_from_starting() {
	settings, _ := xhr_settings()
	state := &XHRTransportObservation{}
	host := xhr_deferred_host(state)
	mut request := XMLHttpRequest.construct_in_settings(settings, host)
	listener := dom.IDLEventListener.create(&dom.CallbackType{ handle_event: fn [mut request] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
		request.abort()
		return dom.js_undefined()
	} })
	request.as_event_target().add_event_listener_without_options('loadstart', listener)
	request.open('GET', '/xhr-loadstart-abort', true, none, none)!
	request.send()!
	assert state.requests.len == 0
	assert request.state == .unsent
	assert !request.send_flag
}

fn test_reentrant_headers_abort_prevents_incremental_response_body_reading() {
	settings, owner := xhr_settings()
	state := &XHRTransportObservation{}
	host := xhr_deferred_host(state)
	mut request := XMLHttpRequest.construct_in_settings(settings, host)
	listener := dom.IDLEventListener.create(&dom.CallbackType{ handle_event: fn [mut request] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
		if request.state == .headers_received { request.abort() }
		return dom.js_undefined()
	} })
	request.as_event_target().add_event_listener_without_options('readystatechange', listener)
	request.open('GET', '/xhr-headers-abort', true, none, none)!
	request.send()!
	body := fetch.Body.streaming()
	xhr_resolve_transport(state, 0, xhr_transport_response(state.requests[0], body))
	xhr_run_queued_work(owner)
	assert request.state == .unsent
	assert !body.stream_locked()
	assert request.received_bytes.len == 0
}
