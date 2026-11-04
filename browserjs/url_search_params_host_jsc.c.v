// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// URLSearchParams.{cpp,idl}, URLSearchParamsIterator.cpp and the pinned
// libweb_bindings constructor, argument, union, record and iterable generators.
@[has_globals]
module browserjs

import domurl
import libjs


__global url_search_params_bindings_ = map[voidptr]&URLSearchParamsHost{}

pub fn (mut host URLSearchParamsHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	owner := voidptr(&runtime)
	if previous := url_search_params_bindings_[owner] {
		if voidptr(previous) == voidptr(&host) { return }
		return error('URLSearchParams binding already belongs to another native owner')
	}
	host.runtime = &runtime
	host.to_dom_string = runtime.evaluate_host_value(r'(function(value){return `${value}`})')!
	handle := voidptr(&host)
	mut methods := []voidptr{}
	names := ['size', 'append', 'delete', 'get', 'getAll', 'has', 'set', 'sort', 'toString', 'keys',
		'values', 'entries', 'forEach', 'next']
	lengths := [0, 2, 1, 1, 1, 1, 2, 0, 0, 0, 0, 0, 1, 0]
	for index, name in names {
		function_name := if name == 'size' { 'get size' } else { name }
		methods << runtime.make_native_value_host_function(function_name, lengths[index], fn [handle, name] (receiver voidptr, args []voidptr) !voidptr {
			mut host := unsafe { &URLSearchParamsHost(handle) }
			return host.operate(name, receiver, args) or { return host.exception(err) }
		})!
	}
	convert := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &URLSearchParamsHost(handle) }
		return host.string_value(host.usv_string(host.argument(args, 0))!) or {
			return host.exception(err)
		}
	})!
	construct := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &URLSearchParamsHost(handle) }
		return host.construct(args) or { return host.exception(err) }
	})!
	factory := runtime.evaluate_host_value(url_search_params_native_factory)!
	defer { runtime.release_javascript_value(factory) }
	installed := runtime.call_javascript_function(factory, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		host.array(methods)!,
		convert,
		construct,
		C.JSContextGetGlobalObject(runtime.context),
	])!
	host.prototype = runtime.retain_javascript_value(runtime.binding_property(installed,
		'prototype')!)!
	host.iterator_prototype = runtime.retain_javascript_value(runtime.binding_property(installed,
		'iteratorPrototype')!)!
	host.constructor = runtime.retain_javascript_value(runtime.binding_property(installed,
		'constructor')!)!
	host.iterator_result = runtime.retain_javascript_value(runtime.binding_property(installed,
		'iteratorResult')!)!
	url_search_params_bindings_[owner] = &host
	runtime.add_close_handler(fn [handle, owner] () {
		mut host := unsafe { &URLSearchParamsHost(handle) }
		host.close()
		url_search_params_bindings_.delete(owner)
	})
}

fn (host &URLSearchParamsHost) exception(reason IError) IError {
	return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(reason))
}

fn (host &URLSearchParamsHost) argument(args []voidptr, index int) voidptr {
	if index < args.len { return args[index] }
	return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
}

fn (host &URLSearchParamsHost) record(value voidptr) !&URLSearchParamsHostRecord {
	if host.closed { return error('TypeError: URLSearchParams binding is closed') }
	record := host.by_wrapper[value] or {
		return error('TypeError: Not an object of type URLSearchParams')
	}
	if voidptr(record.host) != voidptr(host) {
		return error('TypeError: Not an object of type URLSearchParams')
	}
	return record
}

fn (mut host URLSearchParamsHost) wrap(params &domurl.URLSearchParams) !voidptr {
	if host.closed { return error('TypeError: URLSearchParams binding is closed') }
	native := voidptr(params)
	if record := host.records[native] { return record.object }
	mut record := &URLSearchParamsHostRecord{
		host:   host
		params: params
	}
	object := C.JSObjectMake(host.runtime.context, unsafe { nil }, unsafe { nil })
	C.JSObjectSetPrototype(host.runtime.context, object, host.prototype)
	record.object = host.runtime.retain_javascript_value(object)!
	host.records[native] = record
	host.by_wrapper[object] = record
	return object
}

pub fn (mut runtime Runtime) javascript_url_search_params(params &domurl.URLSearchParams) !voidptr {
	mut host := url_search_params_bindings_[voidptr(&runtime)] or {
		return error('URLSearchParams binding is unavailable')
	}
	return host.wrap(params)
}

fn (runtime &Runtime) url_search_params_host() ?&URLSearchParamsHost {
	return url_search_params_bindings_[voidptr(runtime)] or { return none }
}

pub fn (runtime &Runtime) native_url_search_params(value voidptr) !&domurl.URLSearchParams {
	host := url_search_params_bindings_[voidptr(runtime)] or {
		return error('URLSearchParams binding is unavailable')
	}
	return host.record(value)!.params
}

fn (host &URLSearchParamsHost) usv_string(value voidptr) !string {
	return host.runtime.url_binding_dom_string(host.to_dom_string, value)!.to_well_formed_utf8()
}

fn (mut host URLSearchParamsHost) string_value(text string) !voidptr {
	return host.runtime.javascript_utf16_string(libjs.utf16_string(text))
}

fn (mut host URLSearchParamsHost) array(values []voidptr) !voidptr {
	mut exception := unsafe { nil }
	actual := C.vox_jsc_JSObjectMakeArray(host.runtime.context, uint(values.len), values.data, &exception)
	if exception != unsafe { nil } {
		return host.exception(host.runtime.actual_javascript_exception(exception))
	}
	return host.runtime.retain_javascript_value(actual)
}

fn (host &URLSearchParamsHost) at(array voidptr, index int) !voidptr {
	mut exception := unsafe { nil }
	value := C.vox_jsc_JSObjectGetPropertyAtIndex(host.runtime.context, array, u32(index), &exception)
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	return value
}

fn (host &URLSearchParamsHost) length(array voidptr) !int {
	value := host.runtime.binding_property(array, 'length')!
	mut exception := unsafe { nil }
	length := C.vox_jsc_JSValueToNumber(host.runtime.context, value, &exception)
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	if length > 2147483647 { return error('RangeError: Converted sequence exceeds the V span') }
	return int(length)
}

fn (mut host URLSearchParamsHost) construct(args []voidptr) !voidptr {
	kind := host.runtime.native_utf16_string(host.argument(args, 1))!.str()
	data := host.argument(args, 2)
	mut params := &domurl.URLSearchParams(unsafe { nil })
	if kind == 'string' {
		params = domurl.URLSearchParams.from_string(host.runtime.native_utf16_string(data)!.str())
	} else {
		mut sequence := [][]string{}
		for index in 0 .. host.length(data)! {
			pair := host.at(data, index)!
			mut values := []string{}
			for element in 0 .. host.length(pair)! {
				values << host.runtime.native_utf16_string(host.at(pair, element)!)!.str()
			}
			sequence << values
		}
		if kind == 'sequence' {
			// All generated USVString conversions finish before Source checks
			// pair lengths. Preserve its actual SimpleException message.
			for pair in sequence {
				if pair.len != 2 {
					return error('TypeError: Expected each pair to contain exactly 2 items')
				}
			}
			params = domurl.URLSearchParams.from_sequence(sequence)!
		} else {
			// OrderedHashMap::set overwrites a normalized duplicate key in
			// its original position, after every property conversion.
			mut record := map[string]string{}
			for pair in sequence {
				record[pair[0]] = pair[1]
			}
			params = domurl.URLSearchParams.from_record(record)
		}
	}
	object := host.wrap(params)!
	C.JSObjectSetPrototype(host.runtime.context, object, host.argument(args, 0))
	return object
}

fn (mut host URLSearchParamsHost) iterator(params &domurl.URLSearchParams, kind domurl.URLSearchParamsIteratorKind) !voidptr {
	object := C.JSObjectMake(host.runtime.context, unsafe { nil }, unsafe { nil })
	C.JSObjectSetPrototype(host.runtime.context, object, host.iterator_prototype)
	host.runtime.retain_javascript_value(object)!
	host.iterators[object] = &URLSearchParamsIteratorHostRecord{
		iterator: domurl.URLSearchParamsIterator.create(params, kind)
		kind:     kind
	}
	return object
}

fn (mut host URLSearchParamsHost) next(receiver voidptr) !voidptr {
	if host.closed { return error('TypeError: URLSearchParams binding is closed') }
	record := host.iterators[receiver] or {
		return error('TypeError: Not an object of type URLSearchParamsIterator')
	}
	mut iterator := record.iterator
	step := iterator.next()
	mut value := C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
	if !step.done {
		value = match record.kind {
			.key {
				host.string_value(step.key)!
			}
			.value {
				host.string_value(step.value)!
			}
			.key_value {
				host.array([host.string_value(step.key)!, host.string_value(step.value)!])!
			}
		}
	}
	return host.runtime.call_javascript_function(host.iterator_result,
		C.vox_jsc_JSValueMakeUndefined(host.runtime.context), [value,
		C.vox_jsc_JSValueMakeBoolean(host.runtime.context, step.done)])
}

fn (mut host URLSearchParamsHost) operate(name string, receiver voidptr, args []voidptr) !voidptr {
	if name == 'next' { return host.next(receiver) }
	mut params := host.record(receiver)!.params
	required := if name in ['append', 'set'] {
		2
	} else if name in ['delete', 'get', 'getAll', 'has', 'forEach'] {
		1
	} else {
		0
	}
	if args.len < required {
		return error('TypeError: ${name} requires at least ${required} arguments')
	}
	if name == 'forEach' {
		callback := host.argument(args, 0)
		if !C.JSValueIsObject(host.runtime.context, callback)
			|| !C.JSObjectIsFunction(host.runtime.context, callback) {
			return error('TypeError: URLSearchParams callback is not a function')
		}
		// The pinned iterable generator calls JS::call directly, preserving
		// thisArg and the original abrupt completion; no Promise adoption.
		handle := voidptr(&host)
		this_arg := host.argument(args, 1)
		params.for_each(fn [handle, callback, this_arg, receiver] (value string, key string) ! {
			mut host := unsafe { &URLSearchParamsHost(handle) }
			host.runtime.call_javascript_function(callback, this_arg, [
				host.string_value(value)!,
				host.string_value(key)!,
				receiver,
			])!
		})!
		return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
	}
	if name == 'size' { return C.vox_jsc_JSValueMakeNumber(host.runtime.context, f64(params.size())) }
	if name == 'toString' { return host.string_value(params.to_string()) }
	if name == 'keys' { return host.iterator(params, .key) }
	if name == 'values' { return host.iterator(params, .value) }
	if name == 'entries' { return host.iterator(params, .key_value) }
	if name == 'sort' {
		params.sort()
		return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
	}
	key := host.usv_string(host.argument(args, 0))!
	mut value := ?string(none)
	if name in ['append', 'set'] || (name in ['delete', 'has']
		&& !C.JSValueIsUndefined(host.runtime.context, host.argument(args, 1))) {
		value = host.usv_string(host.argument(args, 1))!
	}
	match name {
		'append' {
			params.append(key, value or { '' })
		}
		'set' {
			params.set(key, value or { '' })
		}
		'delete' {
			params.delete_(key, value)
		}
		'get' {
			if found := params.get(key) { return host.string_value(found) }
			return C.vox_jsc_JSValueMakeNull(host.runtime.context)
		}
		'getAll' {
			mut values := []voidptr{}
			for found in params.get_all(key) {
				values << host.string_value(found)!
			}
			return host.array(values)
		}
		'has' {
			return C.vox_jsc_JSValueMakeBoolean(host.runtime.context, params.has(key, value))
		}
		else {
			return error('TypeError: Unknown URLSearchParams operation')
		}
	}

	return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
}

const url_search_params_native_factory = r'(function(methods,usv,construct,global){
 "use strict";
 const define=Object.defineProperty,create=Object.create,get=Object.getOwnPropertyDescriptor,getProto=Object.getPrototypeOf;
 const apply=Reflect.apply,ownKeys=Reflect.ownKeys,T=TypeError,P=Proxy,iteratorSymbol=Symbol.iterator,tag=Symbol.toStringTag;
 const prototype=create(Object.prototype),iteratorPrototype=create(getProto(getProto([][iteratorSymbol]())));
 define(prototype,"size",{get:methods[0],enumerable:true,configurable:true});
 const names=["append","delete","get","getAll","has","set","sort","toString","keys","values","entries","forEach"];
 for(let i=0;i<names.length;i++)define(prototype,names[i],{value:methods[i+1],writable:true,enumerable:true,configurable:true});
 define(prototype,iteratorSymbol,{value:methods[11],writable:true,configurable:true});
 define(prototype,tag,{value:"URLSearchParams",configurable:true});
 define(iteratorPrototype,"next",{value:methods[13],writable:true,enumerable:true,configurable:true});
 define(iteratorPrototype,tag,{value:"URLSearchParams Iterator",configurable:true});
 function object(value){return value!==null&&(typeof value==="object"||typeof value==="function")}
 function method(value){const m=value[iteratorSymbol];if(m==null)return undefined;if(typeof m!=="function")throw new T("Iterator method is not a function");return m}
 // The pinned sequence conversion caches next and does not IteratorClose on
 // element conversion failures. Pair length checks occur in native create.
 function sequence(value,m,convert){if(!object(value)||m===undefined)throw new T("Initializer is not iterable");const iterator=apply(m,value,[]);if(!object(iterator))throw new T("Initializer is not iterable");const next=iterator.next,result=[];let index=0;for(;;){if(typeof next!=="function")throw new T("Iterator next is not a function");const step=apply(next,iterator,[]);if(!object(step))throw new T("Iterator result is not an object");if(step.done)return result;const item=convert(step.value);define(result,index++,{value:item,writable:true,enumerable:true,configurable:true})}}
 function pair(value){if(!object(value))throw new T("Pair is not an object");return sequence(value,method(value),usv)}
 function init(value){if(value===undefined)return ["string",""];if(!object(value))return ["string",usv(value)];const m=method(value);if(m!==undefined)return ["sequence",sequence(value,m,pair)];const result=[],keys=ownKeys(value);let index=0;for(let i=0;i<keys.length;i++){const key=keys[i],desc=get(value,key);if(desc===undefined||!desc.enumerable)continue;const name=usv(key),entry=usv(value[key]);define(result,index++,{value:[name,entry],writable:true,enumerable:true,configurable:true})}return ["record",result]}
 const URLSearchParams=new P(function URLSearchParams(){throw new T("URLSearchParams constructor must be called with \u0027new\u0027")},{construct(target,args,newTarget){let selected=newTarget.prototype;if(!object(selected))selected=prototype;const converted=init(args[0]);return construct(selected,converted[0],converted[1])}});
 define(URLSearchParams,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:URLSearchParams,writable:true,configurable:true});
 define(global,"URLSearchParams",{value:URLSearchParams,writable:true,configurable:true});
 return {prototype,iteratorPrototype,constructor:URLSearchParams,iteratorResult(value,done){return {value,done}}};
})'
