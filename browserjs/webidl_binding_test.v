module browserjs

import webidl

fn C.vox_jsc_JSValueMakeBoolean(context voidptr, value bool) voidptr
fn C.vox_jsc_JSValueMakeNumber(context voidptr, value f64) voidptr
fn C.JSObjectMake(context voidptr, object_class voidptr, data voidptr) voidptr
fn C.vox_jsc_JSObjectSetProperty(context voidptr, object voidptr, name voidptr, value voidptr, attributes u32, exception &voidptr)

@[heap]
struct NativeBindingJobs {
mut:
	jobs []fn ()
}

fn (mut jobs NativeBindingJobs) context() webidl.PromiseContext {
	return webidl.PromiseContext{
		job_scheduler: fn [mut jobs] (job fn ()) { jobs.jobs << job }
	}
}

fn (mut jobs NativeBindingJobs) drain() {
	mut count := 0
	for jobs.jobs.len > 0 {
		count++
		assert count < 100
		job := jobs.jobs[0]
		jobs.jobs.delete(0)
		job()
	}
}

fn native_binding_converter(runtime &Runtime) JavaScriptWebIDLValueConverter {
	return fn [runtime] (value webidl.Value) !voidptr {
		if value.kind == .runtime_value { return runtime.actual_webidl_value(value) }
		if value.kind == .undefined { return C.vox_jsc_JSValueMakeUndefined(runtime.context) }
		if value.kind == .boolean { return C.vox_jsc_JSValueMakeBoolean(runtime.context, value.boolean_value) }
		if value.kind == .number { return C.vox_jsc_JSValueMakeNumber(runtime.context, value.number_value) }
		if value.kind == .object {
			object := C.JSObjectMake(runtime.context, unsafe { nil }, unsafe { nil })
			convert := native_binding_converter(runtime)
			for name, property in value.object_value {
				key := js_source_string(name)
				mut exception := unsafe { nil }
				C.vox_jsc_JSObjectSetProperty(runtime.context, object, key, convert(property)!, 0, &exception)
				C.JSStringRelease(key)
				if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
			}
			return object
		}
		return error('Unexpected IDL argument kind in focused native binding fixture')
	}
}

fn test_actual_jsc_callback_keeps_receiver_arguments_pending_thenable_and_original_rejection() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut jobs := &NativeBindingJobs{}
	context := jobs.context()
	convert := native_binding_converter(runtime)
	receiver := runtime.evaluate_host_value('globalThis.nativeReceiver={};nativeReceiver')!
	chunk := runtime.evaluate_host_value('globalThis.nativeChunk={};nativeChunk.self=nativeChunk;nativeChunk')!
	function := runtime.evaluate_host_value('(function(chunk){"use strict";globalThis.correctCallback=this===nativeReceiver&&chunk===nativeChunk;return {then(resolve,reject){globalThis.nativeThenResolve=resolve;globalThis.nativeThenReject=reject}}})')!
	callback := runtime.webidl_promise_callback(function, context, convert)!
	result := webidl.invoke_callback(callback, runtime.webidl_value(receiver)!, [runtime.webidl_value(chunk)!])!
	mut native := result.promise_value_ or { panic('missing native callback capability') }
	assert native.state == .pending
	assert runtime.evaluate_host('correctCallback')! == 'true'
	runtime.evaluate_host('nativeThenResolve(nativeChunk)')!
	assert native.state == .fulfilled
	assert runtime.actual_webidl_value(native.result)! == chunk
	throwing := runtime.evaluate_host_value('(function(){throw nativeChunk})')!
	throwing_callback := runtime.webidl_promise_callback(throwing, context, convert)!
	bound := webidl.CallbackType{
		callback: throwing_callback.callback
		promise_context: context
		operation_returns_promise: .yes
	}
	rejected := webidl.invoke_promise_callback(bound, none, []webidl.Value{})
	assert rejected.state == .rejected
	assert runtime.actual_webidl_value(rejected.result)! == chunk
	getter := runtime.evaluate_host_value('(function(){return {get then(){throw nativeChunk}}})')!
	getter_callback := runtime.webidl_promise_callback(getter, context, convert)!
	getter_result := webidl.invoke_callback(getter_callback, none, []webidl.Value{})!
	getter_native := getter_result.promise_value_ or { panic('missing native getter rejection capability') }
	assert getter_native.state == .rejected
	assert runtime.actual_webidl_value(getter_native.result)! == chunk
	if _ := runtime.webidl_promise_callback(chunk, context, convert) { assert false } else { assert err.msg().contains('not callable') }
}

fn test_native_capability_wraps_same_real_jsc_promise_and_releases_settled_resolver_roots() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut jobs := &NativeBindingJobs{}
	context := jobs.context()
	convert := native_binding_converter(runtime)
	chunk := runtime.evaluate_host_value('globalThis.nativePromiseChunk={};nativePromiseChunk')!
	value := runtime.webidl_value(chunk)!
	mut native := webidl.create_promise_for(context)
	baseline := runtime.protected_values_.len
	first := runtime.javascript_webidl_promise(native, convert)!
	second := runtime.javascript_webidl_promise(native, convert)!
	assert first == second
	assert runtime.protected_values_.len == baseline + 3
	runtime.define_value_host_function('__nativeCapability', fn [first] (_ voidptr, _ []voidptr) !voidptr { return first })!
	runtime.evaluate_host('globalThis.nativeCapability=__nativeCapability();globalThis.nativeSettled=false;nativeCapability.then(value=>{nativeSettled=value.value===nativePromiseChunk})')!
	native.resolve(webidl.object_value({'value': value, 'done': webidl.boolean_value(false)}))
	assert runtime.evaluate_host('nativeSettled')! == 'false'
	jobs.drain()
	assert runtime.evaluate_host('nativeSettled')! == 'true'
	assert runtime.protected_values_.len == baseline + 1
	assert runtime.javascript_webidl_promise(native, convert)! == first
	assert runtime.evaluate_host('nativeCapability instanceof Promise && __nativeCapability()===nativeCapability')! == 'true'
	assert runtime.evaluate_host('nativeCapability.then(value=>globalThis.actualReadResult=value);void 0')! == 'undefined'
	assert runtime.evaluate_host('actualReadResult.value===nativePromiseChunk && actualReadResult.done===false')! == 'true'
	assert runtime.take_document_state_dirty()
	mut distinct := webidl.create_promise_for(context)
	other := runtime.javascript_webidl_promise(distinct, convert)!
	assert other != first
	distinct.resolve(webidl.undefined_value())
	jobs.drain()
}

fn test_native_jsc_promise_bridge_preserves_actual_rejection_conversion_throw_and_closed_owner() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut jobs := &NativeBindingJobs{}
	context := jobs.context()
	convert := native_binding_converter(runtime)
	reason := runtime.evaluate_host_value('globalThis.nativeBindingReason=Symbol("original source reason");nativeBindingReason')!
	value := runtime.webidl_value(reason)!
	mut native := webidl.create_promise_for(context)
	promise := runtime.javascript_webidl_promise(native, convert)!
	runtime.define_value_host_function('__rejectedNativeCapability', fn [promise] (_ voidptr, _ []voidptr) !voidptr { return promise })!
	runtime.evaluate_host('__rejectedNativeCapability().catch(value=>globalThis.nativeBindingCaught=value)')!
	native.reject(value)
	jobs.drain()
	assert runtime.evaluate_host('nativeBindingCaught===nativeBindingReason')! == 'true'
	mut conversion := webidl.create_promise_for(context)
	failed_conversion := runtime.javascript_webidl_promise(conversion, fn [value] (_ webidl.Value) !voidptr { return webidl.throw_value(value) })!
	runtime.define_value_host_function('__conversionNativeCapability', fn [failed_conversion] (_ voidptr, _ []voidptr) !voidptr { return failed_conversion })!
	runtime.evaluate_host('__conversionNativeCapability().catch(value=>globalThis.nativeConversionCaught=value)')!
	conversion.resolve(webidl.undefined_value())
	jobs.drain()
	assert runtime.evaluate_host('nativeConversionCaught===nativeBindingReason')! == 'true'
	mut typed_conversion := webidl.create_promise_for(context)
	typed_error := runtime.javascript_webidl_promise(typed_conversion, fn (_ webidl.Value) !voidptr { return error('TypeError: actual source conversion failed') })!
	runtime.define_value_host_function('__typedConversionNativeCapability', fn [typed_error] (_ voidptr, _ []voidptr) !voidptr { return typed_error })!
	runtime.evaluate_host('__typedConversionNativeCapability().catch(value=>globalThis.nativeTypedConversionCaught=value)')!
	typed_conversion.resolve(webidl.undefined_value())
	jobs.drain()
	assert runtime.evaluate_host('nativeTypedConversionCaught instanceof TypeError && nativeTypedConversionCaught.message==="actual source conversion failed"')! == 'true'
	mut closing := webidl.create_promise_for(context)
	runtime.javascript_webidl_promise(closing, convert)!
	runtime.close()
	closing.resolve(webidl.undefined_value())
	jobs.drain()
	assert closing.state == .fulfilled
}
