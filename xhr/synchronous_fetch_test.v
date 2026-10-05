module xhr

import dom
import fetch
import html
import http
import platform
import streams

@[heap]
struct SynchronousTransportObservation {
mut:
	requests []&fetch.Request
	stages []string
}

fn synchronous_xhr_settings() &html.EnvironmentSettingsObject {
	mut document := dom.Document.create(dom.URL{value: 'https://example.test/sync-owner'})
	document.set_origin(document.url.origin())
	window := html.WindowModel.create_top_level(document, none, 'sync-owner') or { panic(err) }
	mut realm := &html.ScriptingRealm{}
	object := html.WindowEnvironmentSettingsObject.setup(window, document.url, mut realm, none, document.url, document.origin())
	return object.settings
}

fn synchronous_transport(state &SynchronousTransportObservation, failure bool) &fetch.FetchHost {
	return &fetch.FetchHost{
		perform: fn (_ &fetch.Request) !&fetch.Response { panic('synchronous send called a blocking transport') }
		perform_async: fn [state, failure] (request &fetch.Request) &fetch.PendingResponse {
			mut observation := unsafe { &SynchronousTransportObservation(state) }
			observation.requests << request
			mut mutable_request := unsafe { &fetch.Request(request) }
			pending := fetch.PendingResponse.create(mut mutable_request, none)
			mut response := fetch.Response.create()
			response.url_list = request.url_list.clone()
			response.header_list.append(http.Header{ name: 'Content-Type', value: 'text/plain;charset=UTF-8' })
			response.header_list.append(http.Header{ name: 'Content-Length', value: '11' })
			body := fetch.Body.streaming()
			producer := body.stream()
			response.body = body
			mut headers_timer := platform.Timer.create_single_shot(5, fn [state, pending, response, failure] () {
				mut mutable_pending := unsafe { &fetch.PendingResponse(pending) }
				mutable_pending.resolve(if failure { fetch.Response.network_error('socket failed') } else { response })
				mut observation := unsafe { &SynchronousTransportObservation(state) }
				observation.stages << 'headers'
			})
			headers_timer.start()
			if !failure {
				mut first_timer := platform.Timer.create_single_shot(15, fn [state, producer] () {
					mut network_producer := unsafe { &streams.ReadableStream(producer) }
					network_producer.enqueue(streams.bytes_value('first'.bytes())) or { panic(err) }
					mut observation := unsafe { &SynchronousTransportObservation(state) }
					observation.stages << 'first'
				})
				first_timer.start()
				mut eof_timer := platform.Timer.create_single_shot(25, fn [state, producer] () {
					mut network_producer := unsafe { &streams.ReadableStream(producer) }
					network_producer.enqueue(streams.bytes_value('second'.bytes())) or { panic(err) }
					network_producer.close()
					mut observation := unsafe { &SynchronousTransportObservation(state) }
					observation.stages << 'eof'
				})
				eof_timer.start()
			}
			return pending
		}
	}
}

fn test_synchronous_send_waits_for_real_pending_fetch_and_streamed_eof() {
	if !platform.native_timer_scheduling_available() { return }
	settings := synchronous_xhr_settings()
	state := &SynchronousTransportObservation{}
	mut request := XMLHttpRequest.construct_in_settings(settings, synchronous_transport(state, false))
	request.open('GET', '/sync-stream', false, none, none)!
	request.send()!
	assert state.stages == ['headers', 'first', 'eof']
	assert state.requests.len == 1
	assert request.fetch_request_?.done
	assert request.state == .done
	assert !request.send_flag
	assert request.status() == 200
	assert request.response_text()! == 'firstsecond'
	assert request.events.map(it.type_) == ['readystatechange', 'readystatechange', 'load', 'loadend']
	assert request.events[request.events.len - 2].loaded() == 11
	assert request.events[request.events.len - 2].total() == 11
	assert !request.timeout_timer_active
}

fn test_synchronous_send_throws_fetch_errors_without_async_progress_events() {
	if !platform.native_timer_scheduling_available() { return }
	settings := synchronous_xhr_settings()
	state := &SynchronousTransportObservation{}
	mut request := XMLHttpRequest.construct_in_settings(settings, synchronous_transport(state, true))
	request.open('GET', '/sync-error', false, none, none)!
	mut threw := false
	request.send() or {
		threw = true
		assert err.msg().contains('NetworkError')
	}
	assert threw
	assert state.stages == ['headers']
	assert request.state == .done
	assert !request.send_flag
	assert request.status() == 0
	assert request.events.map(it.type_) == ['readystatechange']
}
