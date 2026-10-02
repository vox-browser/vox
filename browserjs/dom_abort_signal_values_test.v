module browserjs

import dom
import webidl

@[heap]
struct NativeAbortObservations {
mut:
	calls []string
}

fn test_actual_dom_abort_preserves_jsc_reason_thrown_completion_and_dependent_signal_identity() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	reason := runtime.evaluate_host_value('globalThis.reasonCoercions=0;({toString(){reasonCoercions++;throw new Error("unexpected coercion")}})')!
	native_reason := runtime.webidl_value(reason)!
	mut signal := dom.AbortSignal.new()
	dependent := dom.AbortSignal.any([signal])!
	mut seen := &NativeAbortObservations{}
	_ := signal.add_abort_algorithm(fn [signal, dependent, mut seen] () {
		assert signal.aborted() && dependent.aborted()
		seen.calls << 'first'
	})
	removed := signal.add_abort_algorithm(fn [mut seen] () { seen.calls << 'removed' }) or { panic('missing abort id') }
	signal.remove_abort_algorithm(removed)
	_ := signal.add_abort_algorithm(fn [mut seen] () { seen.calls << 'second' })
	listener := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [signal, mut seen] (event &dom.Event, target ?&dom.EventTarget) dom.JSValue {
			assert event.type_name() == 'abort'
			assert event.is_trusted()
			assert voidptr(target or { panic('missing actual abort target') }) == voidptr(signal)
			assert signal.abort_algorithms.len == 0
			seen.calls << 'event'
			return dom.js_undefined()
		}
	})
	signal.add_event_listener_without_options('abort', listener)
	signal.signal_abort(dom.js_webidl_value(native_reason))
	assert seen.calls == ['first', 'second', 'event']
	assert runtime.actual_webidl_value(signal.reason().as_webidl_value()!)! == reason
	assert runtime.actual_webidl_value(dependent.reason().as_webidl_value()!)! == reason
	if _ := signal.throw_if_aborted() { assert false } else {
		assert runtime.actual_webidl_value(webidl.exception_value(err))! == reason
	}
	signal.signal_abort(dom.js_string('second abort'))
	assert seen.calls == ['first', 'second', 'event']
	assert runtime.evaluate_host('reasonCoercions')! == '0'
}

fn test_dom_actual_undefined_selects_one_native_abort_exception_and_scalar_throw_keeps_value() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	undefined := runtime.webidl_value(runtime.evaluate_host_value('undefined')!)!
	assert undefined.runtime_value_?.is_undefined
	mut signal := dom.AbortSignal.new()
	signal.signal_abort(dom.js_webidl_value(undefined))
	assert signal.aborted()
	reason := signal.reason().as_webidl_value()!
	exception := reason.dom_exception_ or { panic('missing actual default DOMException record') }
	assert exception.name() == 'AbortError'
	assert exception.message() == 'Aborted without reason'
	if _ := signal.throw_if_aborted() { assert false } else {
		assert voidptr(webidl.exception_value(err).dom_exception_?) == voidptr(exception)
	}
	mut scalar := dom.AbortSignal.new()
	scalar.signal_abort(dom.js_number(42))
	if _ := scalar.throw_if_aborted() { assert false } else {
		value := webidl.exception_value(err)
		assert value.kind == .number && value.number_value == 42
	}
}

fn test_dom_native_value_carrier_uses_owning_engine_boolean_string_and_same_value_operations() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	false_value := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('false')!)!)
	true_value := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('({})')!)!)
	assert !false_value.native_boolean_value()!
	assert true_value.native_boolean_value()!
	first_nan := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('NaN')!)!)
	second_nan := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('0/0')!)!)
	positive_zero := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('0')!)!)
	negative_zero := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('-0')!)!)
	runtime.evaluate_host('Object.is=function(){throw new Error("must use captured SameValue")};')!
	assert first_nan.native_same_value(second_nan)!
	assert !positive_zero.native_same_value(negative_zero)!
	actual := runtime.evaluate_host_value('({toString(){return "actual DOM string"}})')!
	value := dom.js_webidl_value(runtime.webidl_value(actual)!)
	assert value.to_string_value() == 'actual DOM string'
}
