// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// MediaSource/SourceBuffer/List IDL and PlatformObject indexed properties.
module browserjs

import dom
import libjs
import math
import mediasourceextensions


fn (mut host MediaSourceHost) install_buffer_bindings() ! {
	mut runtime := unsafe { &Runtime(host.runtime) }
	runtime.install_quota_exceeded_error_binding()!
	runtime.install_time_ranges_binding()!
	intrinsics := runtime.evaluate_host_value(crypto_buffer_source_intrinsics)!
	defer { runtime.release_javascript_value(intrinsics) }
	host.buffer_validation = runtime.retain_javascript_value(runtime.binding_property(intrinsics,
		'validate')!)!
	host.buffer_copy =
		runtime.retain_javascript_value(runtime.binding_property(intrinsics, 'copy')!)!
	handle := voidptr(&host)
	mut functions := []voidptr{}
	for name in ['sourceBuffers', 'activeSourceBuffers'] {
		functions << runtime.make_native_value_host_function('get ${name}', 0, fn [handle, name] (receiver voidptr, _ []voidptr) !voidptr {
			mut host := unsafe { &MediaSourceHost(handle) }
			source := host.record(receiver) or { return host.exception(err) }
			list := if name == 'sourceBuffers' {
				source.source.source_buffers()
			} else {
				source.source.active_source_buffers()
			}
			return host.wrap_buffer_owner(.list, voidptr(list)) or { return host.exception(err) }
		})!
	}
	functions << runtime.make_native_value_host_function('addSourceBuffer', 1, fn [handle] (receiver voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaSourceHost(handle) }
		return host.add_source_buffer(receiver, args) or { return host.exception(err) }
	})!
	for kind in [MediaBufferHostKind.buffer, .list] {
		names := if kind == .buffer {
			['mode', 'updating', 'buffered', 'timestampOffset', 'onupdatestart', 'onupdate',
				'onupdateend', 'onerror', 'onabort']
		} else {
			['length', 'onaddsourcebuffer', 'onremovesourcebuffer']
		}
		for name in names {
			functions << runtime.make_native_value_host_function('get ${name}', 0, fn [handle, name, kind] (receiver voidptr, _ []voidptr) !voidptr {
				mut host := unsafe { &MediaSourceHost(handle) }
				return host.get_buffer_owner(kind, name, receiver) or { return host.exception(err) }
			})!
			if name in ['updating', 'buffered', 'length'] {
				functions << C.JSValueMakeUndefined(runtime.context)
			} else {
				functions << runtime.make_native_value_host_function('set ${name}', 1, fn [handle, name, kind] (receiver voidptr, args []voidptr) !voidptr {
					mut host := unsafe { &MediaSourceHost(handle) }
					return host.set_buffer_owner(kind, name, receiver, host.argument(args, 0)) or {
						return host.exception(err)
					}
				})!
			}
		}
	}
	for index, name in ['appendBuffer', 'abort', 'changeType', 'remove'] {
		functions << runtime.make_native_value_host_function(name, [1, 0, 1, 2][index], fn [handle, name] (receiver voidptr, args []voidptr) !voidptr {
			mut host := unsafe { &MediaSourceHost(handle) }
			return host.operate_buffer(name, receiver, args) or { return host.exception(err) }
		})!
	}
	indexed := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaSourceHost(handle) }
		return host.buffer_list_index(args) or { return host.exception(err) }
	})!
	mut exception := unsafe { nil }
	array := C.JSObjectMakeArray(runtime.context, uint(functions.len), functions.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.retain_javascript_value(array)!
	defer { runtime.release_javascript_value(array) }
	factory := runtime.evaluate_host_value(media_buffer_native_factory)!
	defer { runtime.release_javascript_value(factory) }
	installed := runtime.call_javascript_function(factory, C.JSValueMakeUndefined(runtime.context), [
		array,
		indexed,
		host.prototype,
		C.JSContextGetGlobalObject(runtime.context),
	])!
	host.buffer_prototype = runtime.retain_javascript_value(runtime.binding_property(installed,
		'buffer')!)!
	host.list_wrap =
		runtime.retain_javascript_value(runtime.binding_property(installed, 'wrapList')!)!
}

fn (host &MediaSourceHost) buffer_owner_record(kind MediaBufferHostKind, object voidptr) !&MediaBufferHostRecord {
	if host.closed { return error('TypeError: MediaSource binding is closed') }
	record := host.buffer_by_wrapper[object] or {
		return error('TypeError: Not an object of type ${kind.webidl_name()}')
	}
	if record.kind != kind { return error('TypeError: Not an object of type ${kind.webidl_name()}') }
	return record
}

fn (mut host MediaSourceHost) wrap_buffer_owner(kind MediaBufferHostKind, native voidptr) !voidptr {
	if host.closed { return error('TypeError: MediaSource binding is closed') }
	if record := host.buffer_records[native] { return record.object }
	mut object := unsafe { nil }
	mut target := unsafe { &dom.EventTarget(nil) }
	if kind == .list {
		object = host.runtime.call_javascript_function(host.list_wrap,
			C.JSValueMakeUndefined(host.runtime.context), [])!
		list := unsafe { &mediasourceextensions.SourceBufferList(native) }
		target = &list.EventTarget
	} else {
		object = C.JSObjectMake(host.runtime.context, unsafe { nil }, unsafe { nil })
		C.JSObjectSetPrototype(host.runtime.context, object, host.buffer_prototype)
		buffer := unsafe { &mediasourceextensions.SourceBuffer(native) }
		target = &buffer.EventTarget
	}
	host.runtime.retain_javascript_value(object)!
	host.runtime.bind_event_target(object, target)!
	record := &MediaBufferHostRecord{
		kind:   kind
		native: native
		object: object
	}
	host.buffer_records[native] = record
	host.buffer_by_wrapper[object] = record
	return object
}

fn (mut host MediaSourceHost) add_source_buffer(receiver voidptr, args []voidptr) !voidptr {
	mut source := host.record(receiver)!.source
	if args.len < 1 { return error('TypeError: addSourceBuffer requires at least 1 argument') }
	buffer := source.add_source_buffer(host.dom_string(args[0])!)!
	return host.wrap_buffer_owner(.buffer, voidptr(buffer))
}

fn (host &MediaSourceHost) buffer_owner_target(record &MediaBufferHostRecord) &dom.EventTarget {
	if record.kind == .buffer {
		buffer := unsafe { &mediasourceextensions.SourceBuffer(record.native) }
		return &buffer.EventTarget
	}
	list := unsafe { &mediasourceextensions.SourceBufferList(record.native) }
	return &list.EventTarget
}

fn (mut host MediaSourceHost) get_buffer_owner(kind MediaBufferHostKind, name string, receiver voidptr) !voidptr {
	record := host.buffer_owner_record(kind, receiver)!
	if name.starts_with('on') {
		return host.runtime.javascript_event_handler(host.buffer_owner_target(record), name[2..])
	}
	if kind == .list {
		list := unsafe { &mediasourceextensions.SourceBufferList(record.native) }
		return C.JSValueMakeNumber(host.runtime.context, f64(list.length()))
	}
	buffer := unsafe { &mediasourceextensions.SourceBuffer(record.native) }
	if name == 'buffered' {
		return host.runtime.javascript_time_ranges(buffer.buffered()!)
	}
	return match name {
		'mode' { host.runtime.binding_string(buffer.mode().webidl_name()) }
		'updating' { C.JSValueMakeBoolean(host.runtime.context, buffer.updating()) }
		else { C.JSValueMakeNumber(host.runtime.context, buffer.timestamp_offset()) }
	}
}

fn (host &MediaSourceHost) buffer_number(value voidptr, restricted bool) !f64 {
	actual := host.runtime.call_javascript_function(host.to_number,
		C.JSValueMakeUndefined(host.runtime.context), [value])!
	mut exception := unsafe { nil }
	number := C.JSValueToNumber(host.runtime.context, actual, &exception)
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	if restricted && (math.is_nan(number) || math.is_inf(number, 0)) {
		return error('TypeError: Expected a finite floating-point number')
	}
	return number
}

fn (mut host MediaSourceHost) set_buffer_owner(kind MediaBufferHostKind, name string, receiver voidptr, value voidptr) !voidptr {
	record := host.buffer_owner_record(kind, receiver)!
	if name.starts_with('on') {
		host.runtime.set_javascript_event_handler(host.buffer_owner_target(record), name[2..],
			value)!
	} else {
		mut buffer := unsafe { &mediasourceextensions.SourceBuffer(record.native) }
		if name == 'mode' {
			// Source ignores enum conversion failures before calling the setter.
			converted := host.dom_string(value) or {
				if err is JavaScriptValueException { host.runtime.release_javascript_value(err.value) }
				return C.JSValueMakeUndefined(host.runtime.context)
			}
			mode := mediasourceextensions.append_mode_from_webidl(converted) or {
				return C.JSValueMakeUndefined(host.runtime.context)
			}
			buffer.set_mode(mode)!
		} else {
			buffer.set_timestamp_offset(host.buffer_number(value, true)!)!
		}
	}
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (host &MediaSourceHost) append_buffer_bytes(value voidptr) ![]u8 {
	host.runtime.call_javascript_function(host.buffer_validation,
		C.JSValueMakeUndefined(host.runtime.context), [value,
		C.JSValueMakeBoolean(host.runtime.context, true)])!
	view := host.runtime.call_javascript_function(host.buffer_copy,
		C.JSValueMakeUndefined(host.runtime.context), [value])!
	mut runtime := unsafe { &Runtime(host.runtime) }
	runtime.retain_javascript_value(view)!
	defer { runtime.release_javascript_value(view) }
	mut exception := unsafe { nil }
	length := C.JSObjectGetTypedArrayByteLength(runtime.context, view, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	if u64(length) > u64(2_147_483_647) {
		return error('InternalError: Not enough memory to allocate')
	}
	mut bytes := []u8{len: int(length)}
	if length > 0 {
		pointer := C.JSObjectGetTypedArrayBytesPtr(runtime.context, view, &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		unsafe { C.memcpy(bytes.data, pointer, length) }
	}
	return bytes
}

fn (mut host MediaSourceHost) operate_buffer(name string, receiver voidptr, args []voidptr) !voidptr {
	record := host.buffer_owner_record(.buffer, receiver)!
	mut buffer := unsafe { &mediasourceextensions.SourceBuffer(record.native) }
	required := if name == 'abort' {
		0
	} else if name == 'remove' {
		2
	} else {
		1
	}
	if args.len < required {
		return error('TypeError: ${name} requires at least ${required} arguments')
	}
	match name {
		'appendBuffer' {
			buffer.append_buffer(host.append_buffer_bytes(args[0])!)!
		}
		'abort' {
			buffer.abort()!
		}
		'changeType' {
			buffer.change_type(host.dom_string(args[0])!)!
		}
		'remove' {
			start := host.buffer_number(args[0], true)!
			end := host.buffer_number(args[1], false)!
			buffer.remove(start, end)!
		}
		else {
			return error('TypeError: Unknown SourceBuffer operation')
		}
	}

	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaSourceHost) buffer_list_index(args []voidptr) !voidptr {
	if args.len == 1 {
		key := libjs.PropertyName.from_utf16(host.runtime.native_utf16_string(args[0])!)
		if !key.is_number() { return C.JSValueMakeUndefined(host.runtime.context) }
		return C.JSValueMakeNumber(host.runtime.context, f64(key.number))
	}
	record := host.buffer_owner_record(.list, args[0])!
	list := unsafe { &mediasourceextensions.SourceBufferList(record.native) }
	index := u32(host.buffer_number(args[1], true)!)
	buffer := list.item(index) or { return C.JSValueMakeUndefined(host.runtime.context) }
	return host.wrap_buffer_owner(.buffer, voidptr(buffer))
}

const media_buffer_native_factory = r'(function(functions,indexed,sourcePrototype,global){
 "use strict";
 const define=Object.defineProperty,create=Object.create,P=Proxy,T=TypeError;
 const get=Reflect.get,set=Reflect.set,has=Reflect.has,getOwn=Reflect.getOwnPropertyDescriptor,defineOwn=Reflect.defineProperty,remove=Reflect.deleteProperty,ownKeys=Reflect.ownKeys;
 define(sourcePrototype,"sourceBuffers",{get:functions[0],enumerable:true,configurable:true});
 define(sourcePrototype,"activeSourceBuffers",{get:functions[1],enumerable:true,configurable:true});
 define(sourcePrototype,"addSourceBuffer",{value:functions[2],writable:true,enumerable:true,configurable:true});
 const buffer=create(global.EventTarget.prototype),list=create(global.EventTarget.prototype);
 let offset=3;
 for(const [prototype,names] of [[buffer,["mode","updating","buffered","timestampOffset","onupdatestart","onupdate","onupdateend","onerror","onabort"]],[list,["length","onaddsourcebuffer","onremovesourcebuffer"]]]){
  for(const name of names){define(prototype,name,{get:functions[offset++],set:functions[offset++],enumerable:true,configurable:true})}
 }
 for(const name of ["appendBuffer","abort","changeType","remove"])define(buffer,name,{value:functions[offset++],writable:true,enumerable:true,configurable:true});
 for(const [name,prototype,target] of [["SourceBuffer",buffer,function SourceBuffer(){}],["SourceBufferList",list,function SourceBufferList(){}]]){
  const illegal=()=>{throw new T("Illegal constructor")},constructor=new P(target,{apply:illegal,construct:illegal});
  Object.setPrototypeOf(constructor,global.EventTarget);define(constructor,"prototype",{value:prototype,writable:false});
  define(prototype,"constructor",{value:constructor,writable:true,configurable:true});define(prototype,Symbol.toStringTag,{value:name,configurable:true});
  define(global,name,{value:constructor,writable:true,configurable:true});
 }
 function arrayIndex(key){return typeof key==="string"?indexed(key):undefined}
 function wrapList(){
  const target=create(list);let wrapper;
  function property(key){const index=arrayIndex(key);if(index===undefined)return undefined;const value=indexed(wrapper,index);return value===undefined?undefined:{value,writable:false,enumerable:true,configurable:true}}
  wrapper=new P(target,{
   getOwnPropertyDescriptor(target,key){return property(key)||getOwn(target,key)},
   get(target,key,receiver){const d=property(key);return d?d.value:get(target,key,receiver)},
   has(target,key){return property(key)!==undefined||has(target,key)},
   set(target,key,value,receiver){if(property(key)!==undefined)return false;return set(target,key,value,receiver)},
   defineProperty(target,key,d){if(arrayIndex(key)!==undefined)return false;return defineOwn(target,key,d)},
   deleteProperty(target,key){if(arrayIndex(key)!==undefined)return property(key)===undefined;return remove(target,key)},
   preventExtensions(){return false},
   ownKeys(target){const keys=[];function append(key){define(keys,keys.length,{value:key,writable:true,enumerable:true,configurable:true})}for(let index=0;index<=4294967295;index++){if(indexed(wrapper,index)===undefined)break;append(`${index}`)}const ordinary=ownKeys(target);for(const key of ordinary)if(typeof key==="string")append(key);for(const key of ordinary)if(typeof key==="symbol")append(key);return keys}
  });return wrapper;
 }
 return {buffer,wrapList};
})'
