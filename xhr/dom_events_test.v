module xhr

import dom

@[heap]
struct XHRDOMEventObservation {
mut:
	types []string
	loaded []f64
	timestamps []f64
}

fn xhr_dom_listener(callback fn (&dom.Event, ?&dom.EventTarget) dom.JSValue) &dom.IDLEventListener {
	return dom.IDLEventListener.create(&dom.CallbackType{ handle_event: callback })
}

fn test_progress_events_reach_real_dom_listeners_with_the_progress_interface_and_payload() {
	global := &XMLHttpRequestGlobal{
		kind: .window
		base_url: 'https://example.test/'
		event_timestamp: fn () f64 { return 123.5 }
	}
	mut request := XMLHttpRequest.create(global)
	state := &XHRDOMEventObservation{}
	listener := xhr_dom_listener(fn [state, request] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
		assert event.interface_ == .progress_event
		assert event.is_trusted()
		assert !event.bubbles() && !event.cancelable() && !event.composed()
		assert (current or { panic('missing current target') }) == request.as_event_target()
		assert (event.target() or { panic('missing event target') }) == request.as_event_target()
		progress := unsafe { &ProgressEvent(event) }
		mut observation := unsafe { &XHRDOMEventObservation(state) }
		observation.types << event.type_
		observation.loaded << progress.loaded()
		observation.timestamps << event.time_stamp()
		assert progress.total() == 4
		assert progress.length_computable()
		return dom.js_undefined()
	})
	request.as_event_target().add_event_listener_without_options('progress', listener)
	request.open('GET', '/data', true, none, none)!
	request.send()!
	request.receive_headers(MockResponse{
		status: 200
		headers: [ResponseHeader{ name: 'Content-Length', value: '4' }]
	})!
	request.receive_chunk('data'.bytes())
	request.complete_response()!
	assert state.types == ['progress', 'progress']
	assert state.loaded == [f64(4), 4]
	assert state.timestamps == [f64(123.5), 123.5]
}

fn test_listener_changes_update_the_actual_xhr_activity_root() {
	mut request := XMLHttpRequest.construct(.window, 'https://example.test/')
	listener := xhr_dom_listener(fn (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue { return dom.js_undefined() })
	request.open('GET', '/active', true, none, none)!
	request.send()!
	assert !request.has_activity_root()
	request.as_event_target().add_event_listener_without_options('progress', listener)
	assert request.has_activity_root()
	request.as_event_target().remove_event_listener_without_options('progress', listener)
	assert !request.has_activity_root()
	request.set_event_handler_callback('load', listener.callback())
	assert request.event_handler_callback('load')? == listener.callback()
	assert request.has_activity_root()
	request.set_event_handler_callback('load', none)
	assert !request.has_activity_root()
}

fn test_upload_listener_flag_and_upload_events_use_the_actual_dom_target() {
	mut request := XMLHttpRequest.construct(.window, 'https://example.test/')
	state := &XHRDOMEventObservation{}
	listener := xhr_dom_listener(fn [state, request] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
		assert (current or { panic('missing upload target') }) == request.upload_object.as_event_target()
		assert event.is_trusted()
		progress := unsafe { &ProgressEvent(event) }
		mut observation := unsafe { &XHRDOMEventObservation(state) }
		observation.types << event.type_
		observation.loaded << progress.loaded()
		return dom.js_undefined()
	})
	request.upload_object.as_event_target().add_event_listener_without_options('progress', listener)
	request.open('POST', '/upload', true, none, none)!
	request.send_text('abcd')!
	assert request.upload_listener
	assert request.upload_object.listeners.len == 0
	request.receive_upload_chunk_length(4)
	request.complete_upload()
	assert state.types == ['progress', 'progress']
	assert state.loaded == [f64(4), 4]
}

fn test_ready_state_events_use_the_base_event_and_allow_reentrant_abort_during_headers() {
	mut request := XMLHttpRequest.construct(.window, 'https://example.test/')
	listener := xhr_dom_listener(fn [mut request] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
		assert event.interface_ == .event
		assert event.is_trusted()
		if request.state == .headers_received { request.abort() }
		return dom.js_undefined()
	})
	request.as_event_target().add_event_listener_without_options('readystatechange', listener)
	request.open('GET', '/reentrant', true, none, none)!
	request.send()!
	request.receive_headers(MockResponse{ status: 200 })!
	assert request.state == .unsent
	assert !request.send_flag
	assert request.status() == 0
}

fn test_event_handler_callbacks_run_through_dom_event_handler_processing() {
	mut request := XMLHttpRequest.construct(.window, 'https://example.test/')
	state := &XHRDOMEventObservation{}
	callback := &dom.CallbackType{ handle_event: fn [state] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
		mut observation := unsafe { &XHRDOMEventObservation(state) }
		observation.types << event.type_
		return dom.js_undefined()
	} }
	request.set_event_handler_callback('load', callback)
	request.open('GET', '/handler', true, none, none)!
	request.send()!
	request.receive_headers(MockResponse{ status: 200 })!
	request.complete_response()!
	assert state.types == ['load']
}
