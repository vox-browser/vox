// Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// HTML/TimeRanges.{cpp,idl}: native wrappers in the calling runtime.
@[has_globals]
module browserjs

import html
import webidl


@[heap]
struct TimeRangesHostRecord {
	ranges &html.TimeRanges
	object voidptr
}

@[heap]
struct TimeRangesBinding {
mut:
	prototype  voidptr
	records    map[voidptr]&TimeRangesHostRecord
	by_wrapper map[voidptr]&TimeRangesHostRecord
}

__global time_ranges_bindings_ = map[voidptr]&TimeRangesBinding{}

pub fn (mut runtime Runtime) install_time_ranges_binding() ! {
	runtime.require_javascript_value_context()!
	runtime.install_dom_exception_binding()!
	owner := voidptr(&runtime)
	if _ := time_ranges_bindings_[owner] { return }
	mut binding := &TimeRangesBinding{}
	mut functions := []voidptr{}
	for name in ['length', 'start', 'end'] {
		functions << runtime.make_native_value_host_function(if name == 'length' {
			'get length'
		} else {
			name
		}, if name == 'length' { 0 } else { 1 }, fn [owner, binding, name] (receiver voidptr, args []voidptr) !voidptr {
			mut runtime := unsafe { &Runtime(owner) }
			return runtime.time_ranges_operation(binding, name, receiver, args) or {
				return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
			}
		})!
	}
	mut exception := unsafe { nil }
	array := C.JSObjectMakeArray(runtime.context, usize(functions.len), functions.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.retain_javascript_value(array)!
	defer { runtime.release_javascript_value(array) }
	factory := runtime.evaluate_host_value(time_ranges_native_factory)!
	defer { runtime.release_javascript_value(factory) }
	binding.prototype = runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.JSValueMakeUndefined(runtime.context),
		[array, C.JSContextGetGlobalObject(runtime.context)])!)!
	time_ranges_bindings_[owner] = binding
	runtime.add_close_handler(fn [owner, binding] () {
		mut retained := unsafe { &TimeRangesBinding(binding) }
		retained.records = {}
		retained.by_wrapper = {}
		time_ranges_bindings_.delete(owner)
	})
}

fn (mut runtime Runtime) time_ranges_operation(binding &TimeRangesBinding, name string, receiver voidptr, args []voidptr) !voidptr {
	runtime.require_javascript_value_context()!
	record := binding.by_wrapper[receiver] or {
		return error('TypeError: Not an object of type TimeRanges')
	}
	if name == 'length' { return C.JSValueMakeNumber(runtime.context, f64(record.ranges.length())) }
	if args.len == 0 { return error('TypeError: ${name} requires at least 1 argument') }
	index := u32(webidl.convert_to_int(runtime.webidl_value(args[0])!, 32, false, .no, .no)!)
	value := if name == 'start' {
		record.ranges.start(index) or { return runtime.time_ranges_index_exception(err) }
	} else {
		record.ranges.end(index) or { return runtime.time_ranges_index_exception(err) }
	}
	return C.JSValueMakeNumber(runtime.context, value)
}

fn (mut runtime Runtime) time_ranges_index_exception(reason IError) IError {
	value := webidl.dom_exception_value(webidl.DOMException.create('IndexSizeError', reason.msg()))
	object := runtime.javascript_dom_exception(value) or { return err }
	return runtime.actual_javascript_exception(object)
}

pub fn (mut runtime Runtime) javascript_time_ranges(ranges &html.TimeRanges) !voidptr {
	runtime.require_javascript_value_context()!
	mut binding := time_ranges_bindings_[voidptr(&runtime)] or {
		return error('TimeRanges binding is unavailable')
	}
	if record := binding.records[voidptr(ranges)] { return record.object }
	object := C.JSObjectMake(runtime.context, unsafe { nil }, unsafe { nil })
	C.JSObjectSetPrototype(runtime.context, object, binding.prototype)
	runtime.retain_javascript_value(object)!
	record := &TimeRangesHostRecord{
		ranges: ranges
		object: object
	}
	binding.records[voidptr(ranges)] = record
	binding.by_wrapper[object] = record
	return object
}

pub fn (runtime &Runtime) native_time_ranges(object voidptr) !&html.TimeRanges {
	runtime.require_javascript_value_context()!
	binding := time_ranges_bindings_[voidptr(runtime)] or {
		return error('TimeRanges binding is unavailable')
	}
	record := binding.by_wrapper[object] or {
		return error('TypeError: Not an object of type TimeRanges')
	}
	return record.ranges
}

const time_ranges_native_factory = r'(function(functions,global){
 "use strict";
 const define=Object.defineProperty,create=Object.create,P=Proxy,T=TypeError;
 const prototype=create(Object.prototype);
 define(prototype,"length",{get:functions[0],enumerable:true,configurable:true});
 for(const [index,name] of [[1,"start"],[2,"end"]])define(prototype,name,{value:functions[index],writable:true,enumerable:true,configurable:true});
 const illegal=()=>{throw new T("Illegal constructor")},constructor=new P(function TimeRanges(){},{apply:illegal,construct:illegal});
 define(constructor,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:constructor,writable:true,configurable:true});
 define(prototype,Symbol.toStringTag,{value:"TimeRanges",configurable:true});
 define(global,"TimeRanges",{value:constructor,writable:true,configurable:true});
 return prototype;
})'
