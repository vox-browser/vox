// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// WebIDL/AbstractOperations.cpp Promise-returning callback + actual adoption.
// JSC performs Call/Promise Resolve at the compact browser's host boundary;
// the native WebIDL capability continues on its owning HTML Promise jobs.
module browserjs

import webidl


fn C.JSObjectIsFunction(context voidptr, object voidptr) bool

// Source Streams algorithms invoke Promise-returning callbacks and resolve the
// start callback's any result. This adapter supplies those native algorithms
// with the real engine Promise Resolve result; synchronous scalar callback
// conversions continue to call the actual function directly.
pub fn (mut runtime Runtime) webidl_promise_callback(function voidptr, context webidl.PromiseContext, convert JavaScriptWebIDLValueConverter) !webidl.CallbackType {
	runtime.require_javascript_value_context()!
	if !C.JSValueIsObject(runtime.context, function) || !C.JSObjectIsFunction(runtime.context, function) {
		return error('TypeError: WebIDL callback is not callable')
	}
	runtime.retain_javascript_value(function)!
	owner_handle := voidptr(&runtime)
	stored_settings := runtime.callback_settings()
	return webidl.CallbackType{
		promise_context: context
		callback: fn [owner_handle, function, context, convert, stored_settings] (receiver webidl.Value, arguments []webidl.Value) !webidl.Value {
			mut owner := unsafe { &Runtime(owner_handle) }
			owner.require_javascript_value_context()!
			owner.prepare_html_callback(stored_settings)
			defer { owner.clean_up_html_callback(stored_settings) }
			defer { owner.mark_document_state_dirty() }
			this_value := convert(receiver)!
			mut actual_arguments := []voidptr{cap: arguments.len}
			for argument in arguments { actual_arguments << convert(argument)! }
			result := owner.call_javascript_function(function, this_value, actual_arguments) or {
				if err is JavaScriptValueException {
					return webidl.throw_value(owner.webidl_value(err.value)!)
				}
				return err
			}
			owner.retain_javascript_value(result)!
			defer { owner.release_javascript_value(result) }
			mut promise := webidl.create_promise_for(context)
			owner.observe_javascript_promise(result, fn [owner_handle, mut promise] (_ voidptr, args []voidptr) !voidptr {
				mut owner := unsafe { &Runtime(owner_handle) }
				mut value := C.vox_jsc_JSValueMakeUndefined(owner.context)
				if args.len > 0 { value = args[0] }
				promise.resolve(owner.webidl_value(value)!)
				return C.vox_jsc_JSValueMakeUndefined(owner.context)
			}, fn [owner_handle, mut promise] (_ voidptr, args []voidptr) !voidptr {
				mut owner := unsafe { &Runtime(owner_handle) }
				mut value := C.vox_jsc_JSValueMakeUndefined(owner.context)
				if args.len > 0 { value = args[0] }
				promise.reject(owner.webidl_value(value)!)
				return C.vox_jsc_JSValueMakeUndefined(owner.context)
			})!
			return webidl.promise_value(promise)
		}
	}
}

// Bindings wrap the same native WebIDL::Promise capability into the same real
// engine Promise. The lookup key is the native capability address, never an
// exposed ID or serialized value. Only the Promise root survives settlement;
// resolve/reject roots are released once the native operation has completed.
pub fn (mut runtime Runtime) javascript_webidl_promise(native &webidl.Promise, convert JavaScriptWebIDLValueConverter) !voidptr {
	return runtime.javascript_webidl_promise_with_converters(native, convert, convert)
}

pub fn (mut runtime Runtime) javascript_webidl_promise_with_converters(native &webidl.Promise, fulfilled JavaScriptWebIDLValueConverter, rejected JavaScriptWebIDLValueConverter) !voidptr {
	runtime.require_javascript_value_context()!
	key := voidptr(native)
	if bridge := runtime.webidl_promise_bridges_[key] { return bridge.capability.promise }
	capability := runtime.create_javascript_promise()!
	mut bridge := &WebIDLJavaScriptPromiseBridge{ runtime: runtime, native: native, capability: capability }
	runtime.webidl_promise_bridges_[key] = bridge
	mut promise := unsafe { &webidl.Promise(native) }
	webidl.react_to_promise(mut promise, fn [mut bridge, fulfilled] (value webidl.Value) !webidl.Value {
		bridge.settle(value, false, fulfilled)
		return webidl.undefined_value()
	}, fn [mut bridge, rejected] (reason webidl.Value) !webidl.Value {
		bridge.settle(reason, true, rejected)
		return webidl.undefined_value()
	})
	return capability.promise
}

fn (mut bridge WebIDLJavaScriptPromiseBridge) settle(value webidl.Value, rejected bool, convert JavaScriptWebIDLValueConverter) {
	if bridge.settled { return }
	bridge.settled = true
	mut owner := unsafe { &Runtime(bridge.runtime) }
	if owner.closed || owner.context != bridge.capability.context { return }
	defer { owner.mark_document_state_dirty() }
	defer {
		owner.release_javascript_value(bridge.capability.resolve)
		owner.release_javascript_value(bridge.capability.reject)
	}
	actual_value := convert(value) or {
		actual_exception := owner.binding_exception_value(err)
		owner.reject_javascript_promise(bridge.capability, actual_exception) or {}
		return
	}
	if rejected { owner.reject_javascript_promise(bridge.capability, actual_value) or {} }
	else { owner.resolve_javascript_promise(bridge.capability, actual_value) or {} }
}

fn (runtime &Runtime) binding_exception_value(exception IError) voidptr {
	if exception is JavaScriptValueException && exception.context == runtime.context { return exception.value }
	if exception is webidl.ValueException {
		if actual := runtime.actual_webidl_value(exception.value) { return actual }
		if exception.value.simple_exception_ != none {
			mut owner := unsafe { &Runtime(runtime) }
			if actual := owner.javascript_simple_exception(exception.value) { return actual }
		}
	}
	mut kind := 'Error'
	mut message := exception.msg()
	for error_kind in ['TypeError', 'RangeError', 'EvalError'] {
		if message.starts_with(error_kind + ':') { kind = error_kind; message = message[error_kind.len + 1..].trim_left(' '); break }
	}
	kind_string := js_source_string(kind)
	kind_value := C.vox_jsc_JSValueMakeString(runtime.context, kind_string)
	C.JSStringRelease(kind_string)
	string_value := js_source_string(message)
	value := C.vox_jsc_JSValueMakeString(runtime.context, string_value)
	C.JSStringRelease(string_value)
	if runtime.value_error_intrinsic_ != unsafe { nil } {
		if actual := runtime.call_engine_function(runtime.value_error_intrinsic_, [kind_value, value]) { return actual }
	}
	mut ignored := unsafe { nil }
	object := C.vox_jsc_JSObjectMakeError(runtime.context, 1, &value, &ignored)
	if ignored == unsafe { nil } { return object }
	return ignored
}
