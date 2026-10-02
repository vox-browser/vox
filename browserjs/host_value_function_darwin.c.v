// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

#include "host_function_darwin.h"

fn C.vox_make_js_host_function(context voidptr, record voidptr, callback fn (voidptr, voidptr, voidptr, usize, &voidptr, &voidptr) voidptr) voidptr
fn C.JSValueProtect(context voidptr, value voidptr)
fn C.JSValueUnprotect(context voidptr, value voidptr)
fn C.JSObjectMakeArray(context voidptr, count usize, arguments &voidptr, exception &voidptr) voidptr
fn C.JSObjectCallAsFunction(context voidptr, function voidptr, receiver voidptr, count usize, arguments &voidptr, exception &voidptr) voidptr
fn C.JSObjectMakeDeferredPromise(context voidptr, resolve &voidptr, reject &voidptr, exception &voidptr) voidptr

fn javascript_core_value_host_function(context voidptr, function voidptr, receiver voidptr, count usize, arguments &voidptr, exception &voidptr) voidptr {
	record := unsafe { &ValueHostFunctionRecord(C.JSObjectGetPrivate(function)) }
	if record.runtime.closed { return host_function_error(context, 'JavaScript runtime is closed', exception) }
	mut args := []voidptr{cap: int(count)}
	for index in 0 .. int(count) { args << unsafe { arguments[index] } }
	result := record.callback(receiver, args) or {
		if err is JavaScriptValueException && err.context == context {
			unsafe { *exception = err.value }
			return C.JSValueMakeUndefined(context)
		}
		return host_function_error(context, err.msg(), exception)
	}
	if result == unsafe { nil } { return C.JSValueMakeUndefined(context) }
	return result
}

// Protect/unprotect refers to the real JSC GC root API. Runtime.close releases
// every retained value before releasing its context; no native handle outlives
// the context in which it was created.
pub fn (mut runtime Runtime) retain_javascript_value(value voidptr) !voidptr {
	runtime.require_javascript_value_context()!
	if value == unsafe { nil } { return error('Cannot retain a missing JavaScript value') }
	C.JSValueProtect(runtime.context, value)
	runtime.protected_values_ << value
	return value
}

pub fn (mut runtime Runtime) release_javascript_value(value voidptr) {
	if runtime.closed || runtime.context == unsafe { nil } { return }
	for index, retained in runtime.protected_values_ {
		if retained == value {
			runtime.protected_values_.delete(index)
			C.JSValueUnprotect(runtime.context, value)
			return
		}
	}
}

pub fn (mut runtime Runtime) make_value_host_function(callback ValueHostFunction) !voidptr {
	runtime.require_javascript_value_context()!
	record := &ValueHostFunctionRecord{ runtime: runtime, callback: callback }
	function := C.vox_make_js_host_function(runtime.context, record, javascript_core_value_host_function)
	runtime.value_host_functions_ << record
	return runtime.retain_javascript_value(function)
}

pub fn (mut runtime Runtime) evaluate_host_value(source string) !voidptr {
	runtime.require_javascript_value_context()!
	script := js_source_string(source)
	defer { C.JSStringRelease(script) }
	mut exception := unsafe { nil }
	value := C.JSEvaluateScript(runtime.context, script, unsafe { nil }, unsafe { nil }, 1, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	return runtime.retain_javascript_value(value)
}

fn (mut runtime Runtime) initialize_javascript_value_intrinsics() ! {
	// Capture the actual engine intrinsics before author scripts can replace
	// global Reflect/Promise properties. Native Promise adoption remains JSC's
	// Resolve function, including then getter access and thenable job scheduling.
	runtime.value_call_intrinsic_ = runtime.evaluate_host_value('(function(){const apply=Reflect.apply;return function(callback,receiver,args){return apply(callback,receiver,args)}})()')!
	runtime.promise_observe_intrinsic_ = runtime.evaluate_host_value('(function(){const apply=Reflect.apply,then=Promise.prototype.then;return function(promise,fulfilled,rejected){return apply(then,promise,[fulfilled,rejected])}})()')!
}

fn (runtime &Runtime) actual_javascript_exception(value voidptr) IError {
	mut owner := unsafe { &Runtime(runtime) }
	owner.retain_javascript_value(value) or { return err }
	return JavaScriptValueException{runtime.context, value}
}

fn (runtime &Runtime) call_engine_function(function voidptr, arguments []voidptr) !voidptr {
	mut exception := unsafe { nil }
	value := C.JSObjectCallAsFunction(runtime.context, function, unsafe { nil }, usize(arguments.len), arguments.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	return value
}

pub fn (runtime &Runtime) call_javascript_function(function voidptr, receiver voidptr, arguments []voidptr) !voidptr {
	runtime.require_javascript_value_context()!
	mut exception := unsafe { nil }
	array := C.JSObjectMakeArray(runtime.context, usize(arguments.len), arguments.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	return runtime.call_engine_function(runtime.value_call_intrinsic_, [function, receiver, array])
}

pub fn (mut runtime Runtime) create_javascript_promise() !JavaScriptPromiseCapability {
	runtime.require_javascript_value_context()!
	mut resolve := unsafe { nil }
	mut reject := unsafe { nil }
	mut exception := unsafe { nil }
	promise := C.JSObjectMakeDeferredPromise(runtime.context, &resolve, &reject, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	return JavaScriptPromiseCapability{
		context: runtime.context
		promise: runtime.retain_javascript_value(promise)!
		resolve: runtime.retain_javascript_value(resolve)!
		reject: runtime.retain_javascript_value(reject)!
	}
}

pub fn (runtime &Runtime) resolve_javascript_promise(capability JavaScriptPromiseCapability, value voidptr) ! {
	runtime.require_javascript_value_context()!
	if capability.context != runtime.context { return error('Promise capability belongs to another JavaScriptCore context') }
	runtime.call_engine_function(capability.resolve, [value])!
}

pub fn (runtime &Runtime) reject_javascript_promise(capability JavaScriptPromiseCapability, reason voidptr) ! {
	runtime.require_javascript_value_context()!
	if capability.context != runtime.context { return error('Promise capability belongs to another JavaScriptCore context') }
	runtime.call_engine_function(capability.reject, [reason])!
}

pub fn (mut runtime Runtime) release_javascript_promise(capability JavaScriptPromiseCapability) {
	if capability.context != runtime.context { return }
	runtime.release_javascript_value(capability.promise)
	runtime.release_javascript_value(capability.resolve)
	runtime.release_javascript_value(capability.reject)
}

pub fn (mut runtime Runtime) observe_javascript_promise(value voidptr, fulfilled ValueHostFunction, rejected ValueHostFunction) ! {
	runtime.require_javascript_value_context()!
	capability := runtime.create_javascript_promise()!
	on_fulfilled := runtime.make_value_host_function(fulfilled)!
	on_rejected := runtime.make_value_host_function(rejected)!
	runtime.call_engine_function(runtime.promise_observe_intrinsic_, [capability.promise, on_fulfilled, on_rejected])!
	runtime.resolve_javascript_promise(capability, value)!
}
