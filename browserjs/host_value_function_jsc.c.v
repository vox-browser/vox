// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
@[has_globals]
module browserjs

import webidl
import platform


#include "host_function_darwin.h"

fn C.vox_make_js_value_host_function(context voidptr, record voidptr) voidptr
fn C.vox_install_js_value_host_function(context voidptr, name &char, record voidptr) bool
fn C.vox_make_js_native_value_host_function(context voidptr, name voidptr) voidptr
fn C.JSValueProtect(context voidptr, value voidptr)
fn C.JSValueUnprotect(context voidptr, value voidptr)
fn C.vox_jsc_JSObjectMakeArray(context voidptr, count uint, arguments &voidptr, exception &voidptr) voidptr
fn C.vox_jsc_JSObjectCallAsFunction(context voidptr, function voidptr, receiver voidptr, count uint, arguments &voidptr, exception &voidptr) voidptr
fn C.vox_jsc_JSObjectMakeDeferredPromise(context voidptr, resolve &voidptr, reject &voidptr, exception &voidptr) voidptr
fn C.vox_jsc_JSValueToObject(context voidptr, value voidptr, exception &voidptr) voidptr

__global native_value_host_functions_ = map[voidptr]&ValueHostFunctionRecord{}

@[export: 'vox_jsc_value_host_function']
fn javascript_core_value_host_function(context voidptr, function voidptr, receiver voidptr, count uint, arguments &voidptr, exception &voidptr) voidptr {
	record := unsafe { &ValueHostFunctionRecord(C.JSObjectGetPrivate(function)) }
	return invoke_value_host_function_record(record, context, receiver, count, arguments, exception)
}

@[export: 'vox_jsc_native_value_host_function']
fn javascript_core_native_value_host_function(context voidptr, function voidptr, receiver voidptr, count uint, arguments &voidptr, exception &voidptr) voidptr {
	record := native_value_host_function_record(function) or {
		return host_function_error(context, 'Native JavaScript function binding is closed', exception)
	}
	return invoke_value_host_function_record(record, context, receiver, count, arguments, exception)
}

fn native_value_host_function_record(function voidptr) ?&ValueHostFunctionRecord {
	return native_value_host_functions_[function] or { return none }
}

fn invoke_value_host_function_record(record &ValueHostFunctionRecord, context voidptr, receiver voidptr, count uint, arguments &voidptr, exception &voidptr) voidptr {
	if record.runtime.closed { return host_function_error(context, 'JavaScript runtime is closed', exception) }
	// Native callbacks can create streams, promises and wrappers retained by
	// the realm after this engine entry. Keep those allocations out of the
	// caller's temporary evaluation/delivery arena, including exceptional exits.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut args := []voidptr{cap: int(count)}
	for index in 0 .. int(count) { args << unsafe { arguments[index] } }
	result := record.callback(receiver, args) or {
		if err is JavaScriptValueException && err.context == context {
			unsafe { *exception = err.value }
			return C.vox_jsc_JSValueMakeUndefined(context)
		}
		if err is webidl.ValueException {
			if err.value.simple_exception_ != none {
				mut owner := record.runtime
				value := owner.javascript_simple_exception(err.value) or { return host_function_error(context, err.msg(), exception) }
				unsafe { *exception = value }
				return C.vox_jsc_JSValueMakeUndefined(context)
			}
			value := record.runtime.actual_webidl_value(err.value) or {
				return host_function_error(context, err.msg(), exception)
			}
			unsafe { *exception = value }
			return C.vox_jsc_JSValueMakeUndefined(context)
		}
		return host_function_error(context, err.msg(), exception)
	}
	if result == unsafe { nil } { return C.vox_jsc_JSValueMakeUndefined(context) }
	return result
}

// Protect/unprotect refers to the real JSC GC root API. Runtime.close releases
// every retained value before releasing its context; no native handle outlives
// the context in which it was created.
pub fn (mut runtime Runtime) retain_javascript_value(value voidptr) !voidptr {
	runtime.require_javascript_value_context()!
	if value == unsafe { nil } { return error('Cannot retain a missing JavaScript value') }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	C.JSValueProtect(runtime.context, value)
	runtime.remember_protected_value(value)
	return value
}

pub fn (mut runtime Runtime) release_javascript_value(value voidptr) {
	if runtime.closed || runtime.context == unsafe { nil } { return }
	if runtime.forget_protected_value(value) {
		C.JSValueUnprotect(runtime.context, value)
	}
}

pub fn (mut runtime Runtime) make_value_host_function(callback ValueHostFunction) !voidptr {
	runtime.require_javascript_value_context()!
	record := &ValueHostFunctionRecord{ runtime: runtime, callback: callback }
	function := C.vox_make_js_value_host_function(runtime.context, record)
	runtime.value_host_functions_ << record
	return runtime.retain_javascript_value(function)
}

// Real JSC native function, including Function prototype, native source text,
// and no [[Construct]]. Exact actual function references retain their source
// host records until the owning Runtime closes; this is not full wrapper GC.
pub fn (mut runtime Runtime) make_native_value_host_function(name string, length int, callback ValueHostFunction) !voidptr {
	runtime.require_javascript_value_context()!
	record := &ValueHostFunctionRecord{runtime: &runtime, callback: callback}
	actual_name := js_source_string(name)
	defer { C.JSStringRelease(actual_name) }
	function := C.vox_make_js_native_value_host_function(runtime.context, actual_name)
	if function == unsafe { nil } { return error('JavaScriptCore native function creation failed') }
	runtime.retain_javascript_value(function)!
	runtime.call_engine_function(runtime.value_function_metadata_intrinsic_, [function, C.vox_jsc_JSValueMakeString(runtime.context, actual_name), C.vox_jsc_JSValueMakeNumber(runtime.context, f64(length))])!
	native_value_host_functions_[function] = record
	runtime.value_host_functions_ << record
	runtime.add_close_handler(fn [function] () { native_value_host_functions_.delete(function) })
	return function
}

pub fn (mut runtime Runtime) evaluate_host_value(source string) !voidptr {
	runtime.require_javascript_value_context()!
	runtime.prepare_html_script()
	defer { runtime.clean_up_html_script() }
	script := js_source_string(source)
	defer { C.JSStringRelease(script) }
	mut exception := unsafe { nil }
	value := C.vox_jsc_JSEvaluateScript(runtime.context, script, unsafe { nil }, unsafe { nil }, 1, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	return runtime.retain_javascript_value(value)
}

fn (mut runtime Runtime) initialize_javascript_value_intrinsics() ! {
	// Capture the actual engine intrinsics before author scripts can replace
	// global Reflect/Promise properties. Native Promise adoption remains JSC's
	// Resolve function, including then getter access and thenable job scheduling.
	runtime.value_call_intrinsic_ = runtime.evaluate_host_value('(function(){const apply=Reflect.apply;return function(callback,receiver,args,caught){if(!caught)return apply(callback,receiver,args);try{return [true,apply(callback,receiver,args)]}catch(error){return [false,error]}}})()')!
	runtime.promise_observe_intrinsic_ = runtime.evaluate_host_value('(function(){const apply=Reflect.apply,then=Promise.prototype.then;return function(promise,fulfilled,rejected){return apply(then,promise,[fulfilled,rejected])}})()')!
	runtime.value_error_intrinsic_ = runtime.evaluate_host_value('(function(){const E=Error,T=TypeError,R=RangeError,V=EvalError,F=ReferenceError,U=URIError;return function(kind,message){return new (kind==="TypeError"?T:kind==="RangeError"?R:kind==="EvalError"?V:kind==="ReferenceError"?F:kind==="URIError"?U:E)(message)}})()')!
	runtime.value_same_intrinsic_ = runtime.evaluate_host_value('Object.is')!
	// JSC's C JSValueToNumber accepts BigInt. Unary plus performs genuine
	// ECMAScript ToNumber before the C API reads the resulting Number.
	runtime.value_number_intrinsic_ = runtime.evaluate_host_value('(function(value){return +value})')!
	// BigInt.asIntN performs ToBigInt (including the Number rejection) and
	// exactly the signed low-64-bit projection used by Wasm i64 conversion.
	runtime.value_bigint_int64_intrinsic_ = runtime.evaluate_host_value('(function(){const asIntN=BigInt.asIntN;return function(value){return asIntN(64,value)}})()')!
	// Runtime/Value.cpp::ToPrimitive(number) + ToBigInt. JSC's BigInt
	// constructor accepts Number, so reject that primitive before delegating
	// its remaining primitive cases. Retain full width before Table bounds.
	runtime.value_bigint_intrinsic_ = runtime.evaluate_host_value(bigint_conversion_intrinsic)!
	// Source CreateBuiltinFunction name/length have Configurable only.
	runtime.value_function_metadata_intrinsic_ = runtime.evaluate_host_value('(function(){const define=Object.defineProperty;return function(callback,name,length){define(callback,"name",{value:name,writable:false,enumerable:false,configurable:true});define(callback,"length",{value:length,writable:false,enumerable:false,configurable:true})}})()')!
}

const bigint_conversion_intrinsic = r'(function(){
 const B=BigInt,T=TypeError,apply=Reflect.apply,exoticKey=Symbol.toPrimitive;
 const object=value=>value!==null&&(typeof value==="object"||typeof value==="function");
 const primitive=input=>{
  if(!object(input))return input;
  const exotic=input[exoticKey];
  if(exotic!==undefined&&exotic!==null){
   if(typeof exotic!=="function")throw new T("@@toPrimitive is not callable");
   const result=apply(exotic,input,["number"]);
   if(!object(result))return result;
   throw new T("@@toPrimitive returned an object");
  }
  for(let index=0;index<2;index++){
   const name=index===0?"valueOf":"toString";
   const method=input[name];
   if(typeof method==="function"){
    const result=apply(method,input,[]);
    if(!object(result))return result;
   }
  }
  throw new T("Cannot convert object to primitive value");
 };
 return function(value){const result=primitive(value);if(typeof result==="number")throw new T("Cannot convert number to BigInt");return B(result)};
})()'

fn (runtime &Runtime) actual_javascript_exception(value voidptr) IError {
	mut owner := unsafe { &Runtime(runtime) }
	owner.retain_javascript_value(value) or { return err }
	return JavaScriptValueException{runtime.context, value}
}

fn (runtime &Runtime) call_engine_function(function voidptr, arguments []voidptr) !voidptr {
	// JSC drains Promise reactions before this API entry returns. Native task
	// completions must keep their owning HTML realm active through that drain.
	runtime.prepare_html_script()
	defer { runtime.clean_up_html_script() }
	mut exception := unsafe { nil }
	value := C.vox_jsc_JSObjectCallAsFunction(runtime.context, function, unsafe { nil }, uint(arguments.len), arguments.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	return value
}

pub fn (runtime &Runtime) call_javascript_function(function voidptr, receiver voidptr, arguments []voidptr) !voidptr {
	runtime.require_javascript_value_context()!
	if runtime.can_call_with_object_receiver(function, receiver) {
		return runtime.call_with_object_receiver(function, receiver, arguments)
	}
	mut exception := unsafe { nil }
	array := C.vox_jsc_JSObjectMakeArray(runtime.context, uint(arguments.len), arguments.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	return runtime.call_engine_function(runtime.value_call_intrinsic_, [function, receiver, array])
}

// A native DOM method forwards into an implementation written in JavaScript.
// Catch inside that implementation's API entry, then return the original thrown
// value through the native callback. JSC otherwise reports this intermediate
// API exception to the inspector even when the outer script handles it.
pub fn (runtime &Runtime) forward_javascript_function(function voidptr, receiver voidptr, arguments []voidptr) !voidptr {
	runtime.require_javascript_value_context()!
	context := runtime.context
	mut exception := unsafe { nil }
	array := C.vox_jsc_JSObjectMakeArray(context, uint(arguments.len), arguments.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	outcome := runtime.call_engine_function(runtime.value_call_intrinsic_,
		[function, receiver, array, C.vox_jsc_JSValueMakeBoolean(context, true)])!
	runtime.require_javascript_value_context()!
	if runtime.context != context { return error('JavaScript context changed during native forwarding') }
	C.JSValueProtect(context, outcome)
	defer { C.JSValueUnprotect(context, outcome) }
	object := C.vox_jsc_JSValueToObject(context, outcome, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	completed := C.vox_jsc_JSObjectGetPropertyAtIndex(context, object, 0, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	value := C.vox_jsc_JSObjectGetPropertyAtIndex(context, object, 1, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	if !C.JSValueToBoolean(context, completed) { return runtime.actual_javascript_exception(value) }
	return value
}

pub fn (mut runtime Runtime) create_javascript_promise() !JavaScriptPromiseCapability {
	runtime.require_javascript_value_context()!
	mut resolve := unsafe { nil }
	mut reject := unsafe { nil }
	mut exception := unsafe { nil }
	promise := C.vox_jsc_JSObjectMakeDeferredPromise(runtime.context, &resolve, &reject, &exception)
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
	mut observation := &JavaScriptPromiseObservation{ runtime: runtime, capability: capability }
	observation.fulfilled = runtime.make_value_host_function(fn [mut observation, fulfilled] (receiver voidptr, args []voidptr) !voidptr {
		defer { observation.release_roots() }
		return fulfilled(receiver, args)
	}) or { observation.release_roots(); return err }
	observation.rejected = runtime.make_value_host_function(fn [mut observation, rejected] (receiver voidptr, args []voidptr) !voidptr {
		defer { observation.release_roots() }
		return rejected(receiver, args)
	}) or { observation.release_roots(); return err }
	runtime.call_engine_function(runtime.promise_observe_intrinsic_, [capability.promise, observation.fulfilled, observation.rejected]) or {
		observation.release_roots()
		return err
	}
	runtime.resolve_javascript_promise(capability, value) or {
		observation.release_roots()
		return err
	}
}

fn (mut observation JavaScriptPromiseObservation) release_roots() {
	if observation.released { return }
	observation.released = true
	mut runtime := unsafe { &Runtime(observation.runtime) }
	if runtime.closed || runtime.context != observation.capability.context { return }
	runtime.release_javascript_promise(observation.capability)
	if observation.fulfilled != unsafe { nil } { runtime.release_javascript_value(observation.fulfilled) }
	if observation.rejected != unsafe { nil } { runtime.release_javascript_value(observation.rejected) }
}
