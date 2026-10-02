module streams

import dom
import webidl

@[heap]
struct DOMStreamAbortCalls {
mut:
	values []string
}

fn test_writable_signal_owns_actual_dom_event_target_default_reason_and_reentrant_state() {
	mut calls := &DOMStreamAbortCalls{}
	mut stream := WritableStream.create(StreamRealm{}, UnderlyingSink{
		abort: fn [mut calls] (_ Value) ! { calls.values << 'sink abort' }
	}, QueuingStrategy{})!
	mut signal := stream.controller().signal().dom_signal()
	_ := signal.add_abort_algorithm(fn [mut stream, mut calls] () {
		calls.values << 'DOM algorithm'
		closed := stream.close()
		assert closed.state() == .fulfilled
	})
	listener := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [signal, mut calls] (event &dom.Event, target ?&dom.EventTarget) dom.JSValue {
			assert event.is_trusted()
			assert voidptr(target or { panic('missing DOM signal target') }) == voidptr(signal)
			calls.values << 'DOM event'
			return dom.js_undefined()
		}
	})
	signal.add_event_listener_without_options('abort', listener)
	result := stream.abort(undefined_value())
	assert result.state() == .fulfilled
	assert stream.state() == .closed
	assert calls.values == ['DOM algorithm', 'DOM event']
	assert stream.controller().signal().aborted()
	reason := stream_value_to_webidl(stream.controller().signal().reason())
	assert reason.dom_exception_?.name() == 'AbortError'
	assert reason.dom_exception_?.message() == 'Aborted without reason'
}

fn test_real_dom_signal_runs_pipe_abort_algorithm_and_removes_completed_registration() {
	mut native := dom.AbortSignal.new()
	mut signal := AbortSignal.from_dom(native)
	mut source := ReadableStream.create(StreamRealm{}, UnderlyingSource{}, QueuingStrategy{})!
	mut destination := WritableStream.create(StreamRealm{}, UnderlyingSink{}, QueuingStrategy{})!
	piped := source.pipe_to(mut destination, StreamPipeOptions{signal: signal})
	assert source.locked() && destination.locked()
	assert native.abort_algorithms.len == 1
	native.signal_abort(dom.js_string('actual DOM abort'))
	assert signal.aborted()
	assert piped.state() == .rejected
	assert piped.reason() == 'actual DOM abort'
	assert !source.locked() && !destination.locked()
	assert native.abort_algorithms.len == 0
	assert native.abort_algorithm_order.len == 0
	mut completed_native := dom.AbortSignal.new()
	completed_signal := AbortSignal.from_dom(completed_native)
	mut closed_source := ReadableStream.create(StreamRealm{}, UnderlyingSource{}, QueuingStrategy{})!
	closed_source.close()
	mut closed_sink := WritableStream.create(StreamRealm{}, UnderlyingSink{}, QueuingStrategy{})!
	completion := closed_source.pipe_to(mut closed_sink, StreamPipeOptions{signal: completed_signal})
	assert completion.state() == .fulfilled
	assert !completed_signal.aborted()
	assert completed_native.abort_algorithms.len == 0
}

fn test_public_signal_record_lazily_creates_actual_dom_backend() {
	mut signal := &AbortSignal{}
	assert !signal.aborted()
	assert signal.reason().kind == .undefined
	actual := signal.dom_signal()
	signal.abort(string_value('native facade'))
	assert voidptr(signal.dom_signal()) == voidptr(actual)
	assert actual.aborted()
	assert actual.reason().string_data == 'native facade'
	if _ := actual.throw_if_aborted() { assert false } else {
		assert webidl.exception_value(err).string_value == 'native facade'
	}
}
