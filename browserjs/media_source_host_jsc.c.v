// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// MediaSource.{cpp,idl}: real platform identity, owner, state and EventTarget.
@[has_globals]
module browserjs

import mediasourceextensions
import webidl


__global media_source_bindings_ = map[voidptr]&MediaSourceHost{}

pub fn (mut host MediaSourceHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	owner := voidptr(&runtime)
	if previous := media_source_bindings_[owner] {
		if voidptr(previous) == voidptr(&host) { return }
		return error('MediaSource binding already belongs to another native owner')
	}
	runtime.install_event_target_binding()!
	host.runtime = &runtime
	host.to_dom_string = runtime.evaluate_host_value(r'(function(value){return `${value}`})')!
	host.to_number = runtime.evaluate_host_value(r'(function(value){return +value})')!
	handle := voidptr(&host)
	mut functions := []voidptr{}
	for name in ['readyState', 'duration', 'onsourceopen', 'onsourceended', 'onsourceclose',
		'canConstructInDedicatedWorker'] {
		functions << runtime.make_native_value_host_function('get ${name}', 0, fn [handle, name] (receiver voidptr, _ []voidptr) !voidptr {
			mut host := unsafe { &MediaSourceHost(handle) }
			return host.get(name, receiver) or { return host.exception(err) }
		})!
		if name in ['readyState', 'canConstructInDedicatedWorker'] {
			functions << C.JSValueMakeUndefined(runtime.context)
		} else {
			functions << runtime.make_native_value_host_function('set ${name}', 1, fn [handle, name] (receiver voidptr, args []voidptr) !voidptr {
				mut host := unsafe { &MediaSourceHost(handle) }
				return host.set(name, receiver, host.argument(args, 0)) or {
					return host.exception(err)
				}
			})!
		}
	}
	for name in ['endOfStream', 'isTypeSupported'] {
		functions << runtime.make_native_value_host_function(name, if name == 'endOfStream' {
			0
		} else {
			1
		}, fn [handle, name] (receiver voidptr, args []voidptr) !voidptr {
			mut host := unsafe { &MediaSourceHost(handle) }
			return host.operate(name, receiver, args) or { return host.exception(err) }
		})!
	}
	construct := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaSourceHost(handle) }
		// Source create_for_constructor uses the actual Window's this_impl().
		source :=
			mediasourceextensions.MediaSource.create_for_constructor(host.settings.global_object())
		return host.wrap(source, host.argument(args, 0)) or { return host.exception(err) }
	})!
	mut exception := unsafe { nil }
	array := C.JSObjectMakeArray(runtime.context, uint(functions.len), functions.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.retain_javascript_value(array)!
	defer { runtime.release_javascript_value(array) }
	factory := runtime.evaluate_host_value(media_source_native_factory)!
	defer { runtime.release_javascript_value(factory) }
	installed := runtime.call_javascript_function(factory, C.JSValueMakeUndefined(runtime.context), [
		array,
		construct,
		C.JSContextGetGlobalObject(runtime.context),
	])!
	host.prototype = runtime.retain_javascript_value(runtime.binding_property(installed,
		'prototype')!)!
	host.constructor = runtime.retain_javascript_value(runtime.binding_property(installed,
		'constructor')!)!
	host.install_buffer_bindings()!
	media_source_bindings_[owner] = &host
	runtime.add_close_handler(fn [handle, owner] () {
		mut host := unsafe { &MediaSourceHost(handle) }
		host.close()
		media_source_bindings_.delete(owner)
	})
}

fn (host &MediaSourceHost) exception(reason IError) IError {
	if reason is JavaScriptValueException { return reason }
	message := reason.msg()
	if separator := message.index(':') {
		name := message[..separator]
		if name == 'QuotaExceededError' {
			mut runtime := unsafe { &Runtime(host.runtime) }
			native := webidl.QuotaExceededError.create(message[separator + 1..].trim_left(' '))
			return runtime.actual_javascript_exception(runtime.javascript_quota_exceeded_error(&native) or {
				return err
			})
		}
		if name in ['InvalidStateError', 'NotSupportedError'] {
			mut runtime := unsafe { &Runtime(host.runtime) }
			value := webidl.dom_exception_value(webidl.DOMException.create(name, message[
				separator + 1..].trim_left(' ')))
			return runtime.actual_javascript_exception(runtime.javascript_dom_exception(value) or {
				return err
			})
		}
	}
	return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(reason))
}

fn (host &MediaSourceHost) argument(args []voidptr, index int) voidptr {
	if index < args.len { return args[index] }
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (host &MediaSourceHost) record(value voidptr) !&MediaSourceHostRecord {
	if host.closed { return error('TypeError: MediaSource binding is closed') }
	record := host.by_wrapper[value] or {
		return error('TypeError: Not an object of type MediaSource')
	}
	return record
}

fn (mut host MediaSourceHost) wrap(source &mediasourceextensions.MediaSource, desired_prototype voidptr) !voidptr {
	if host.closed { return error('TypeError: MediaSource binding is closed') }
	if record := host.records[voidptr(source)] { return record.object }
	mut record := &MediaSourceHostRecord{
		host:   host
		source: source
	}
	object := C.JSObjectMake(host.runtime.context, unsafe { nil }, unsafe { nil })
	mut prototype := host.prototype
	if desired_prototype != unsafe { nil }
		&& C.JSValueIsObject(host.runtime.context, desired_prototype) {
		prototype = desired_prototype
	}
	C.JSObjectSetPrototype(host.runtime.context, object, prototype)
	record.object = host.runtime.retain_javascript_value(object)!
	host.runtime.bind_event_target(object, &source.EventTarget)!
	host.records[voidptr(source)] = record
	host.by_wrapper[object] = record
	return object
}

pub fn (mut runtime Runtime) javascript_media_source(source &mediasourceextensions.MediaSource) !voidptr {
	mut host := media_source_bindings_[voidptr(&runtime)] or {
		return error('MediaSource binding is unavailable')
	}
	return host.wrap(source, unsafe { nil })
}

pub fn (runtime &Runtime) native_media_source(value voidptr) !&mediasourceextensions.MediaSource {
	host := media_source_bindings_[voidptr(runtime)] or {
		return error('MediaSource binding is unavailable')
	}
	return host.record(value)!.source
}

fn (host &MediaSourceHost) dom_string(value voidptr) !string {
	actual := host.runtime.call_javascript_function(host.to_dom_string,
		C.JSValueMakeUndefined(host.runtime.context), [value])!
	return host.runtime.native_utf16_string(actual)!.str()
}

fn (mut host MediaSourceHost) get(name string, receiver voidptr) !voidptr {
	if name == 'canConstructInDedicatedWorker' {
		return C.JSValueMakeBoolean(host.runtime.context,
			mediasourceextensions.MediaSource.can_construct_in_dedicated_worker())
	}
	source := host.record(receiver)!.source
	if name == 'readyState' {
		return host.runtime.binding_string(source.ready_state().webidl_name())
	}
	if name == 'duration' { return C.JSValueMakeNumber(host.runtime.context, source.duration()) }
	return host.runtime.javascript_event_handler(&source.EventTarget, name[2..])
}

fn (mut host MediaSourceHost) set(name string, receiver voidptr, value voidptr) !voidptr {
	mut source := host.record(receiver)!.source
	if name == 'duration' {
		// The C API's number conversion accepts BigInt; WebIDL ToNumber does not.
		actual := host.runtime.call_javascript_function(host.to_number,
			C.JSValueMakeUndefined(host.runtime.context), [value])!
		mut exception := unsafe { nil }
		number := C.JSValueToNumber(host.runtime.context, actual, &exception)
		if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
		source.set_duration(number)!
	} else {
		host.runtime.set_javascript_event_handler(&source.EventTarget, name[2..], value)!
	}
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaSourceHost) operate(name string, receiver voidptr, args []voidptr) !voidptr {
	if name == 'isTypeSupported' {
		if args.len == 0 { return error('TypeError: isTypeSupported requires at least 1 argument') }
		return C.JSValueMakeBoolean(host.runtime.context,
			mediasourceextensions.MediaSource.is_type_supported(host.dom_string(args[0])!))
	}
	mut source := host.record(receiver)!.source
	mut ending := ?mediasourceextensions.EndOfStreamError(none)
	if args.len > 0 && !C.JSValueIsUndefined(host.runtime.context, args[0]) {
		ending = mediasourceextensions.end_of_stream_error_from_webidl(host.dom_string(args[0])!)!
	}
	source.end_of_stream(ending)!
	return C.JSValueMakeUndefined(host.runtime.context)
}

const media_source_native_factory = r'(function(functions,construct,global){
 "use strict";
 const define=Object.defineProperty,create=Object.create,setPrototypeOf=Object.setPrototypeOf,T=TypeError,P=Proxy,base=global.EventTarget;
 const prototype=create(base.prototype),names=["readyState","duration","onsourceopen","onsourceended","onsourceclose"];
 for(let i=0;i<names.length;i++)define(prototype,names[i],{get:functions[i*2],set:functions[i*2+1],enumerable:true,configurable:true});
 define(prototype,"endOfStream",{value:functions[12],writable:true,enumerable:true,configurable:true});
 define(prototype,Symbol.toStringTag,{value:"MediaSource",configurable:true});
 const MediaSource=new P(function MediaSource(){throw new T("MediaSource constructor must be called with new")},{construct(target,args,newTarget){let selected=newTarget.prototype;if(selected===null||(typeof selected!=="object"&&typeof selected!=="function"))selected=prototype;return construct(selected)}});
 setPrototypeOf(MediaSource,base);define(MediaSource,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:MediaSource,writable:true,configurable:true});
 define(MediaSource,"canConstructInDedicatedWorker",{get:functions[10],enumerable:true,configurable:true});
 define(MediaSource,"isTypeSupported",{value:functions[13],writable:true,enumerable:true,configurable:true});
 define(global,"MediaSource",{value:MediaSource,writable:true,configurable:true});
 return {prototype,constructor:MediaSource};
})'
