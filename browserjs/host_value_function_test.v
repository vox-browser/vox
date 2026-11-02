module browserjs

fn C.JSGarbageCollect(context voidptr)

@[heap]
struct NativeValueObservations {
mut:
	receiver voidptr
	values []voidptr
	reasons []voidptr
}

fn test_raw_javascript_host_values_preserve_actual_receiver_chunks_symbols_functions_and_cycles() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut seen := &NativeValueObservations{}
	runtime.define_value_host_function('__echoActualValue', fn [mut seen] (receiver voidptr, args []voidptr) !voidptr {
		seen.receiver = receiver
		seen.values << args[0]
		return args[0]
	})!
	assert runtime.evaluate_host('const owner={echo:__echoActualValue};const cyclic={};cyclic.self=cyclic;const symbol=Symbol("source");const callback=()=>42;const view=new Uint8Array([1,2]);owner.echo(cyclic)===cyclic && owner.echo(symbol)===symbol && owner.echo(callback)===callback && owner.echo(view)===view;')! == 'true'
	owner := runtime.evaluate_host_value('owner')!
	assert seen.receiver == owner
	assert seen.values.len == 4
	assert seen.values[0] == runtime.evaluate_host_value('cyclic')!
	assert seen.values[1] == runtime.evaluate_host_value('symbol')!
	assert seen.values[2] == runtime.evaluate_host_value('callback')!
	assert seen.values[3] == runtime.evaluate_host_value('view')!
}

fn test_raw_javascript_callback_preserves_strict_primitive_this_and_actual_thrown_value() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	receiver := runtime.evaluate_host_value('Symbol("actual receiver")')!
	callback := runtime.evaluate_host_value('(function(value){"use strict";return this===value})')!
	result := runtime.call_javascript_function(callback, receiver, [receiver])!
	assert js_string_to_v(runtime.context, result)! == 'true'
	reason := runtime.evaluate_host_value('globalThis.actualReason=Object.freeze({code:"source throw"})')!
	throwing := runtime.evaluate_host_value('(function(){throw actualReason})')!
	runtime.define_value_host_function('__nativeThrowActualReason', fn [runtime, throwing, receiver] (_ voidptr, _ []voidptr) !voidptr {
		return runtime.call_javascript_function(throwing, receiver, []voidptr{})
	})!
	assert runtime.evaluate_host('let caught;try{__nativeThrowActualReason()}catch(reason){caught=reason}caught===actualReason;')! == 'true'
	assert reason != unsafe { nil }
	anonymous_throw := runtime.evaluate_host_value('(function(){throw {code:"retained thrown value"}})')!
	mut retained_reason := unsafe { nil }
	if _ := runtime.call_javascript_function(anonymous_throw, receiver, []voidptr{}) { assert false } else {
		if err is JavaScriptValueException { retained_reason = err.value } else { assert false }
	}
	C.JSGarbageCollect(runtime.context)
	runtime.define_value_host_function('__retainedThrownValue', fn [retained_reason] (_ voidptr, _ []voidptr) !voidptr { return retained_reason })!
	assert runtime.evaluate_host('__retainedThrownValue().code==="retained thrown value"')! == 'true'
}

fn test_actual_javascript_promise_capability_remains_pending_adopts_thenables_and_keeps_identity() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	capability := runtime.create_javascript_promise()!
	runtime.define_value_host_function('__actualNativePromise', fn [capability] (_ voidptr, _ []voidptr) !voidptr { return capability.promise })!
	assert runtime.evaluate_host('const nativePromise=__actualNativePromise();globalThis.results=[];nativePromise.then(value=>results.push(value));nativePromise===__actualNativePromise() && nativePromise instanceof Promise && results.length===0;')! == 'true'
	thenable := runtime.evaluate_host_value('globalThis.actualResult={answer:42};({then(resolve){Promise.resolve().then(()=>resolve(actualResult))}})')!
	runtime.resolve_javascript_promise(capability, thenable)!
	assert runtime.evaluate_host('results.length===1 && results[0]===actualResult;')! == 'true'
	runtime.release_javascript_promise(capability)
	rejection := runtime.create_javascript_promise()!
	runtime.define_value_host_function('__actualRejectedPromise', fn [rejection] (_ voidptr, _ []voidptr) !voidptr { return rejection.promise })!
	_ = runtime.evaluate_host('globalThis.rejectedValue=undefined;__actualRejectedPromise().catch(reason=>rejectedValue=reason)')!
	reason := runtime.evaluate_host_value('globalThis.actualRejectReason=Object.freeze({source:"reject capability"})')!
	runtime.reject_javascript_promise(rejection, reason)!
	assert runtime.evaluate_host('rejectedValue===actualRejectReason')! == 'true'
	runtime.release_javascript_promise(rejection)
}

fn test_actual_javascript_promise_observation_uses_real_engine_thenable_and_rejection_values() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut seen := &NativeValueObservations{}
	value := runtime.evaluate_host_value('globalThis.actualFulfillment={source:"value"};({then(resolve){Promise.resolve().then(()=>resolve(actualFulfillment))}})')!
	runtime.observe_javascript_promise(value, fn [mut seen, runtime] (_ voidptr, args []voidptr) !voidptr {
		seen.values << args[0]
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}, fn [mut seen, runtime] (_ voidptr, args []voidptr) !voidptr {
		seen.reasons << args[0]
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	})!
	_ = runtime.evaluate_host('0')!
	assert seen.values.len == 1
	assert seen.values[0] == runtime.evaluate_host_value('actualFulfillment')!
	assert seen.reasons.len == 0
	throwing := runtime.evaluate_host_value('globalThis.actualRejection=Object.freeze({source:"then getter"});({get then(){throw actualRejection}})')!
	_ = runtime.evaluate_host('Reflect.apply=()=>{throw "overwritten"};Promise.prototype.then=()=>{throw "overwritten"};')!
	runtime.observe_javascript_promise(throwing, fn [mut seen, runtime] (_ voidptr, args []voidptr) !voidptr {
		seen.values << args[0]
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}, fn [mut seen, runtime] (_ voidptr, args []voidptr) !voidptr {
		seen.reasons << args[0]
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	})!
	_ = runtime.evaluate_host('0')!
	assert seen.values.len == 1
	assert seen.reasons.len == 1
	assert seen.reasons[0] == runtime.evaluate_host_value('actualRejection')!
}

fn test_raw_values_remain_rooted_in_actual_gc_and_context_ownership_is_checked() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	mut other := Runtime.create()
	defer { runtime.close(); other.close() }
	value := runtime.evaluate_host_value('({answer:42})')!
	C.JSGarbageCollect(runtime.context)
	callback := runtime.evaluate_host_value('(function(value){return value.answer})')!
	assert js_string_to_v(runtime.context, runtime.call_javascript_function(callback, C.vox_jsc_JSValueMakeUndefined(runtime.context), [value])!)! == '42'
	capability := runtime.create_javascript_promise()!
	if _ := other.resolve_javascript_promise(capability, value) { assert false } else {
		assert err.msg().contains('another JavaScriptCore context')
	}
	runtime.release_javascript_value(value)
	runtime.close()
	assert runtime.protected_values_.len == 0
	assert runtime.value_host_functions_.len == 0
	if _ := runtime.evaluate_host_value('1') { assert false } else { assert err.msg().contains('closed') }
}

fn test_actual_javascript_promise_observation_releases_ephemeral_roots_after_settlement() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut seen := &NativeValueObservations{}
	pending := runtime.create_javascript_promise()!
	value := runtime.evaluate_host_value('({answer:42})')!
	baseline := runtime.protected_values_.len
	runtime.observe_javascript_promise(pending.promise, fn [mut seen, runtime] (_ voidptr, args []voidptr) !voidptr {
		seen.values << args[0]
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}, fn [mut seen, runtime] (_ voidptr, args []voidptr) !voidptr {
		seen.reasons << args[0]
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	})!
	assert runtime.protected_values_.len == baseline + 5
	runtime.resolve_javascript_promise(pending, value)!
	_ = runtime.evaluate_host('0')!
	assert seen.values == [value]
	assert seen.reasons.len == 0
	assert runtime.protected_values_.len == baseline
	failed := runtime.create_javascript_promise()!
	failed_baseline := runtime.protected_values_.len
	runtime.observe_javascript_promise(failed.promise, fn (_ voidptr, _ []voidptr) !voidptr {
		return error('unexpected fulfillment')
	}, fn (_ voidptr, _ []voidptr) !voidptr { return error('reaction exception') })!
	runtime.reject_javascript_promise(failed, value)!
	_ = runtime.evaluate_host('0')!
	assert runtime.protected_values_.len == failed_baseline
	runtime.release_javascript_promise(pending)
	runtime.release_javascript_promise(failed)
}
