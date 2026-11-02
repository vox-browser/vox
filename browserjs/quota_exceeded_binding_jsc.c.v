// Copyright (c) 2025, Shannon Booth <shannon@serenityos.org>
// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// WebIDL/QuotaExceededError.{cpp,idl} generated native engine binding.
@[has_globals]
module browserjs

import libjs
import math
import webidl


fn C.JSObjectSetPrototype(context voidptr, object voidptr, prototype voidptr)
fn C.vox_jsc_JSValueToNumber(context voidptr, value voidptr, exception &voidptr) f64
fn C.vox_jsc_JSValueMakeNull(context voidptr) voidptr

@[heap]
struct QuotaExceededErrorBinding {
mut:
	prototype  voidptr
	to_number  voidptr
	by_wrapper map[voidptr]&webidl.QuotaExceededError
}

__global quota_exceeded_error_bindings_ = map[voidptr]&QuotaExceededErrorBinding{}

pub fn (mut runtime Runtime) install_quota_exceeded_error_binding() ! {
	runtime.install_dom_exception_binding()!
	owner := voidptr(&runtime)
	if _ := quota_exceeded_error_bindings_[owner] { return }
	mut binding := &QuotaExceededErrorBinding{}
	quota_exceeded_error_bindings_[owner] = binding
	binding.to_number = runtime.evaluate_host_value('(function(value){return +value})')!
	construct := runtime.make_value_host_function(fn [owner] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.construct_quota_exceeded_error(args) or {
			return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
		}
	})!
	get := runtime.make_value_host_function(fn [owner, binding] (receiver voidptr, args []voidptr) !voidptr {
		runtime := unsafe { &Runtime(owner) }
		native := binding.by_wrapper[receiver] or {
			return runtime.actual_javascript_exception(runtime.binding_exception_value(error('TypeError: Illegal QuotaExceededError receiver')))
		}
		value := if runtime.binding_dom_string(args[0])! == 'quota' {
			native.quota()
		} else {
			native.requested()
		}
		if number := value { return C.vox_jsc_JSValueMakeNumber(runtime.context, number) }
		return C.vox_jsc_JSValueMakeNull(runtime.context)
	})!
	bootstrap := runtime.evaluate_host_value(quota_exceeded_error_native_bootstrap)!
	defer { runtime.release_javascript_value(bootstrap) }
	binding.prototype = runtime.retain_javascript_value(runtime.call_javascript_function(bootstrap,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), [construct, get])!)!
	runtime.add_close_handler(fn [owner] () { quota_exceeded_error_bindings_.delete(owner) })
}

struct QuotaOptionalDouble {
	value ?f64
}

fn (runtime &Runtime) quota_option(options voidptr, name string) !QuotaOptionalDouble {
	if C.JSValueIsUndefined(runtime.context, options) || C.JSValueIsNull(runtime.context, options) {
		return QuotaOptionalDouble{}
	}
	if !C.JSValueIsObject(runtime.context, options) {
		return error('TypeError: Not an object of type QuotaExceededErrorOptions')
	}
	value := runtime.binding_property(options, name)!
	if C.JSValueIsUndefined(runtime.context, value) { return QuotaOptionalDouble{} }
	mut exception := unsafe { nil }
	binding := quota_exceeded_error_bindings_[voidptr(runtime)] or { return error('QuotaExceededError binding unavailable') }
	converted := runtime.call_javascript_function(binding.to_number, C.vox_jsc_JSValueMakeUndefined(runtime.context), [value])!
	number := C.vox_jsc_JSValueToNumber(runtime.context, converted, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	if math.is_nan(number) || math.is_inf(number, 0) {
		return error('TypeError: Expected ${name} to be a finite floating-point number')
	}
	return QuotaOptionalDouble{ value: number }
}

fn (mut runtime Runtime) construct_quota_exceeded_error(args []voidptr) !voidptr {
	message := if args.len > 0 && !C.JSValueIsUndefined(runtime.context, args[0]) {
		runtime.binding_dom_utf16(args[0])!
	} else {
		libjs.utf16_string('')
	}
	mut options := C.vox_jsc_JSValueMakeUndefined(runtime.context)
	if args.len > 1 { options = args[1] }
	quota := runtime.quota_option(options, 'quota')!
	requested := runtime.quota_option(options, 'requested')!
	native := webidl.QuotaExceededError.construct_utf16(message, webidl.QuotaExceededErrorOptions{ quota: quota.value, requested: requested.value })!
	object := runtime.javascript_quota_exceeded_error(&native)!
	if args.len > 2 && C.JSValueIsObject(runtime.context, args[2]) {
		C.JSObjectSetPrototype(runtime.context, object, args[2])
	}
	return object
}

pub fn (mut runtime Runtime) javascript_quota_exceeded_error(native &webidl.QuotaExceededError) !voidptr {
	runtime.install_quota_exceeded_error_binding()!
	mut binding := quota_exceeded_error_bindings_[voidptr(&runtime)] or { return error('QuotaExceededError binding is unavailable') }
	object := runtime.javascript_dom_exception(webidl.dom_exception_value_for_record(&native.base))!
	if _ := binding.by_wrapper[object] { return object }
	C.JSObjectSetPrototype(runtime.context, object, binding.prototype)
	binding.by_wrapper[object] = native
	return object
}

const quota_exceeded_error_native_bootstrap = r'(function(__ladybirdQuotaExceededConstruct,__ladybirdQuotaExceededGet){
 const define=Object.defineProperty,create=Object.create,setPrototypeOf=Object.setPrototypeOf,apply=Reflect.apply,construct=__ladybirdQuotaExceededConstruct,get=__ladybirdQuotaExceededGet,D=DOMException,T=TypeError;
 function QuotaExceededError(message="",options={}){if(!new.target)throw new T("QuotaExceededError constructor requires new");return construct(message,options,new.target.prototype)}
 setPrototypeOf(QuotaExceededError,D);QuotaExceededError.prototype=create(D.prototype);
 define(QuotaExceededError.prototype,"constructor",{value:QuotaExceededError,writable:true,configurable:true});
 define(QuotaExceededError.prototype,Symbol.toStringTag,{value:"QuotaExceededError",configurable:true});
 for(const property of ["quota","requested"])define(QuotaExceededError.prototype,property,{get:function(){return apply(get,this,[property])},enumerable:true,configurable:true});
 define(QuotaExceededError,"prototype",{writable:false});define(globalThis,"QuotaExceededError",{value:QuotaExceededError,writable:true,configurable:true});
 return QuotaExceededError.prototype;
})'
