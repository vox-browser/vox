// Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// HTML/MediaError.{h,cpp,idl}: native record wrappers in the calling Window realm.
@[has_globals]
module browserjs

import html


@[heap]
struct MediaErrorHostRecord {
	media_error &html.MediaError
	object      voidptr
}

@[heap]
struct MediaErrorBinding {
mut:
	prototype  voidptr
	records    map[voidptr]&MediaErrorHostRecord
	by_wrapper map[voidptr]&MediaErrorHostRecord
	closed     bool
}

__global media_error_bindings_ = map[voidptr]&MediaErrorBinding{}

pub fn (mut runtime Runtime) install_media_error_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if _ := media_error_bindings_[owner] { return }
	mut binding := &MediaErrorBinding{}
	mut getters := []voidptr{}
	for name in ['code', 'message'] {
		getters << runtime.make_native_value_host_function('get ' + name, 0, fn [owner, binding, name] (receiver voidptr, _ []voidptr) !voidptr {
			mut runtime := unsafe { &Runtime(owner) }
			return runtime.media_error_get(binding, name, receiver) or {
				return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
			}
		})!
	}
	mut exception := unsafe { nil }
	array := C.JSObjectMakeArray(runtime.context, usize(getters.len), getters.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.retain_javascript_value(array)!
	defer { runtime.release_javascript_value(array) }
	factory := runtime.evaluate_host_value(media_error_native_factory)!
	defer { runtime.release_javascript_value(factory) }
	binding.prototype = runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.JSValueMakeUndefined(runtime.context), [array, C.JSContextGetGlobalObject(runtime.context)])!)!
	media_error_bindings_[owner] = binding
	runtime.add_close_handler(fn [owner, binding] () {
		mut retained := unsafe { &MediaErrorBinding(binding) }
		retained.closed = true
		retained.records = {}
		retained.by_wrapper = {}
		retained.prototype = unsafe { nil }
		media_error_bindings_.delete(owner)
	})
}

fn (runtime &Runtime) media_error_get(binding &MediaErrorBinding, name string, receiver voidptr) !voidptr {
	runtime.require_javascript_value_context()!
	record := binding.by_wrapper[receiver] or {
		return error('TypeError: Not an object of type MediaError')
	}
	// Receiver identity is native: no author property, Proxy, or prototype read.
	return match name {
		'code' { C.JSValueMakeNumber(runtime.context, f64(record.media_error.code())) }
		'message' { runtime.binding_string(record.media_error.message()) }
		else { return error('Unknown MediaError getter') }
	}
}

pub fn (mut runtime Runtime) javascript_media_error(media_error &html.MediaError) !voidptr {
	runtime.require_javascript_value_context()!
	mut binding := media_error_bindings_[voidptr(&runtime)] or {
		return error('MediaError binding is unavailable')
	}
	if record := binding.records[voidptr(media_error)] { return record.object }
	object := C.JSObjectMake(runtime.context, unsafe { nil }, unsafe { nil })
	C.JSObjectSetPrototype(runtime.context, object, binding.prototype)
	runtime.retain_javascript_value(object)!
	// Keep the actual immutable V record alive, including after the media owner
	// clears/replaces its error. Each runtime supplies its own stable wrapper.
	record := &MediaErrorHostRecord{ media_error: media_error, object: object }
	binding.records[voidptr(media_error)] = record
	binding.by_wrapper[object] = record
	return object
}

pub fn (runtime &Runtime) native_media_error(object voidptr) !&html.MediaError {
	runtime.require_javascript_value_context()!
	binding := media_error_bindings_[voidptr(runtime)] or {
		return error('MediaError binding is unavailable')
	}
	record := binding.by_wrapper[object] or {
		return error('TypeError: Not an object of type MediaError')
	}
	return record.media_error
}

const media_error_native_factory = r'(function(getters,global){
 "use strict";
 const define=Object.defineProperty,create=Object.create,P=Proxy,T=TypeError;
 const prototype=create(Object.prototype);
 for(const [index,name] of [[0,"code"],[1,"message"]])define(prototype,name,{get:getters[index],enumerable:true,configurable:true});
 const illegal=()=>{throw new T("Illegal constructor")},constructor=new P(function MediaError(){},{apply:illegal,construct:illegal});
 define(constructor,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:constructor,writable:true,configurable:true});
 define(prototype,Symbol.toStringTag,{value:"MediaError",configurable:true});
 const constants={MEDIA_ERR_ABORTED:1,MEDIA_ERR_NETWORK:2,MEDIA_ERR_DECODE:3,MEDIA_ERR_SRC_NOT_SUPPORTED:4};
 for(const name of Object.keys(constants))for(const target of [constructor,prototype])define(target,name,{value:constants[name],enumerable:true});
 define(global,"MediaError",{value:constructor,writable:true,configurable:true});
 return prototype;
})'
