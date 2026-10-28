// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// ViewTransition.idl binding transport. DOM and WebIDL own the transition,
// callback queue, captured records and promises; JavaScriptCore owns JS values.
module browserjs

import dom
import html
import webidl
import x.json2

pub type ViewTransitionReplayHook = fn (&Runtime) !

@[heap]
struct ViewTransitionHostRecord {
	key              int
	callback_promise &webidl.Promise
mut:
	transition &dom.ViewTransition = unsafe { nil }
	subscribed bool
}

@[heap]
pub struct ViewTransitionHost {
	document &dom.Document
	@[required]
	replay   ViewTransitionReplayHook
mut:
	records  map[int]&ViewTransitionHostRecord
	next_key int
	closed   bool
}

pub fn ViewTransitionHost.create(document &dom.Document, replay ViewTransitionReplayHook) !&ViewTransitionHost {
	if document.relevant_settings_object() == unsafe { nil } {
		_ = html.WindowModel.create_top_level(document, none, '')!
	}
	return &ViewTransitionHost{
		document: document
		replay:   replay
	}
}

pub fn (mut host ViewTransitionHost) install(mut runtime Runtime) ! {
	runtime.install_dom_exception_binding()!
	runtime.define_host_function('__ladybirdViewTransition', fn [mut host, mut runtime] (input string) !string {
		return host.call(input, runtime)
	})!
	runtime.add_close_handler(fn [mut host] () {
		host.closed = true
		host.records = {}
	})
}

fn (host &ViewTransitionHost) observe(runtime &Runtime, record &ViewTransitionHostRecord, name string, promise &webidl.Promise) {
	mut native_promise := unsafe { &webidl.Promise(promise) }
	webidl.react_to_promise(mut native_promise, fn [host, runtime, record, name, promise] (_ webidl.Value) !webidl.Value {
		host.notify(runtime, record, name, promise, true, webidl.undefined_value())
		return webidl.undefined_value()
	}, fn [host, runtime, record, name, promise] (reason webidl.Value) !webidl.Value {
		host.notify(runtime, record, name, promise, false, reason)
		return webidl.undefined_value()
	})
}

fn (host &ViewTransitionHost) notify(runtime &Runtime, record &ViewTransitionHostRecord, name string, promise &webidl.Promise, fulfilled bool, reason webidl.Value) {
	if host.closed || runtime.closed { return }
	payload := {
		'key':       json2.Any(record.key)
		'promise':   json2.Any(name)
		'fulfilled': json2.Any(fulfilled)
		'handled':   json2.Any(promise.is_handled)
		'reason':    json2.Any(reason.string_value)
	}
	// JS settlement keeps callback rejection values inside their actual JSC
	// Realm. Only the native callback-rejection identity crosses this transport.
	runtime.evaluate_host('__ladybirdViewTransitionSettle(${json2.encode(payload)})') or { return }
	mut mutable_runtime := unsafe { &Runtime(runtime) }
	mutable_runtime.mark_document_state_dirty()
}

fn (mut host ViewTransitionHost) call(input string, runtime &Runtime) !string {
	if host.closed { return error('InvalidStateError: ViewTransition global has closed') }
	request := canvas_host_object(json2.decode[json2.Any](input)!)!
	method := canvas_host_string(request['method'] or { json2.Any('') })
	if method == 'start' {
		host.next_key++
		key := host.next_key
		mut record := &ViewTransitionHostRecord{
			key:              key
			callback_promise: webidl.create_promise_for(host.document.view_transition_promise_context_)
		}
		host.records[key] = record
		mut callback := ?&dom.CallbackType(none)
		if canvas_host_bool(request['hasCallback'] or { json2.Any(false) }) {
			callback = &dom.CallbackType{
				call_no_args_promise: fn [runtime, record, host] () !&webidl.Promise {
					if host.closed || runtime.closed {
						return error('AbortError: ViewTransition global has closed')
					}
					runtime.evaluate_host('__ladybirdViewTransitionInvoke(${record.key})')!
					// An unresolved callback can mutate DOM before returning its
					// promise. Replay those mutations at the actual invocation too.
					if record.callback_promise.state == .pending { host.replay(runtime)! }
					return record.callback_promise
				}
			}
		}
		mut document := unsafe { &dom.Document(host.document) }
		record.transition = document.start_view_transition(callback)
		return json2.encode(key)
	}
	if method == 'active' {
		transition := host.document.get_active_view_transition() or { return 'null' }
		for key, record in host.records {
			if voidptr(record.transition) == voidptr(transition) { return json2.encode(key) }
		}
		// DirectGetter returns the actual active source object, including one
		// started through the typed API before this JS wrapper was requested.
		host.next_key++
		key := host.next_key
		host.records[key] = &ViewTransitionHostRecord{
			key:              key
			callback_promise: webidl.create_promise_for(host.document.view_transition_promise_context_)
			transition:       transition
		}
		return json2.encode(key)
	}
	key := int(canvas_host_number(request['key'] or { json2.Any(0) }))
	record := host.records[key] or { return error('TypeError: Unknown ViewTransition receiver') }
	match method {
		'subscribe' {
			mut mutable_record := unsafe { &ViewTransitionHostRecord(record) }
			if !record.subscribed {
				mutable_record.subscribed = true
				host.observe(runtime, record, 'ready', record.transition.ready())
				host.observe(runtime, record, 'updateCallbackDone',
					record.transition.update_callback_done())
				host.observe(runtime, record, 'finished', record.transition.finished())
			}
		}
		'skip' {
			record.transition.skip_the_view_transition()
		}
		'settleCallback' {
			// Callback completion must reach the actual DOM before its native
			// fulfillment reaction captures the new committed layout state.
			host.replay(runtime)!
			mut callback_promise := record.callback_promise
			if canvas_host_bool(request['fulfilled'] or { json2.Any(false) }) {
				callback_promise.resolve(webidl.undefined_value())
			} else {
				callback_promise.reject(webidl.string_value('__view_transition_callback_${key}'))
			}
		}
		else {
			return error('TypeError: Unknown ViewTransition operation')
		}
	}

	return 'null'
}
