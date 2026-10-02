module browserjs

import webidl

fn test_webidl_callback_throw_and_promise_reaction_retain_actual_jsc_value() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	reason := runtime.evaluate_host_value('globalThis.actualCompletionReason={};actualCompletionReason.self=actualCompletionReason;actualCompletionReason')!
	native_reason := runtime.webidl_value(reason)!
	callback := webidl.CallbackType{
		operation_returns_promise: .yes
		callback: fn [native_reason] (_ webidl.Value, _ []webidl.Value) !webidl.Value {
			return webidl.throw_value(native_reason)
		}
	}
	result := webidl.invoke_promise_callback(callback, none, []webidl.Value{})
	assert result.state == .rejected
	assert runtime.actual_webidl_value(result.result)! == reason
	wrapped := webidl.invoke_callback(callback, none, []webidl.Value{})!
	native := wrapped.promise_value_ or { panic('missing actual callback capability') }
	assert native.state == .rejected
	assert runtime.actual_webidl_value(native.result)! == reason
	mut fulfilled := webidl.create_resolved_promise(webidl.undefined_value())
	thrown := fulfilled.upon_fulfillment(fn [native_reason] (_ webidl.Value) !webidl.Value {
		return webidl.throw_value(native_reason)
	})
	assert thrown.state == .rejected
	assert runtime.actual_webidl_value(thrown.result)! == reason
	mut rejected := webidl.create_rejected_promise(native_reason)
	rethrown := rejected.upon_rejection(fn (value webidl.Value) !webidl.Value { return webidl.throw_value(value) })
	assert rethrown.state == .rejected
	assert runtime.actual_webidl_value(rethrown.result)! == reason
	runtime.define_value_host_function('__actualWebIDLThrow', fn [native_reason] (_ voidptr, _ []voidptr) !voidptr {
		return webidl.throw_value(native_reason)
	})!
	assert runtime.evaluate_host('let completion;try{__actualWebIDLThrow()}catch(value){completion=value}completion===actualCompletionReason')! == 'true'
}
