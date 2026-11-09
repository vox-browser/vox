// Copyright (c) 2022-2024, Kenneth Myhra <kennethmyhra@serenityos.org>
// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Blob.{h,cpp,idl}: actual records and receiver-realm generated operations.
@[has_globals]
module browserjs

import fileapi
import libjs
import webidl

#include "@DIR/blob_operation.h"
fn C.vox_make_blob_operation_resolver(context voidptr) voidptr

@[export: 'vox_jsc_blob_operation_resolver']
fn javascript_core_blob_operation_resolver(context voidptr, _function voidptr,
	_receiver voidptr, count uint, arguments &voidptr, _exception &voidptr) voidptr {
	if count > 0 {
		if record := blob_record_for_context(context, unsafe { arguments[0] }) {
			return record.host.operation
		}
	}
	return C.vox_jsc_JSValueMakeUndefined(context)
}

__global blob_bindings_ = map[voidptr]&BlobHost{}

// This prerequisite installs the actual record factory and Source prototype.
// Its public constructor is installed by the separate constructor translation.
pub fn (mut host BlobHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	owner := voidptr(&runtime)
	if previous := blob_bindings_[owner] {
		if voidptr(previous) == voidptr(&host) { return }
		return error('Blob binding already belongs to another native owner')
	}
	readable := runtime.readable_stream_host() or { return error('Blob binding requires its actual relevant-realm ReadableStream host') }
	if readable.closed || voidptr(readable.settings) != voidptr(host.settings) {
		return error('Blob binding requires its owning relevant-realm ReadableStream host')
	}
	host.runtime = &runtime
	host.readable = readable
	host.to_dom_string = runtime.evaluate_host_value(r'(function(value){return `${value}`})')!
	handle := voidptr(&host)
	host.operation = runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &BlobHost(handle) }
		name := host.runtime.binding_dom_string(host.argument(args, 0))!
		return host.operate(name, args) or {
			if name in ['text', 'arrayBuffer', 'bytes'] {
				actual := host.runtime.binding_exception_value(err)
				return host.promise(webidl.create_rejected_promise_for(host.settings.stream_promise_context(), host.runtime.webidl_value(actual)!))
			}
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	resolver := runtime.retain_javascript_value(C.vox_make_blob_operation_resolver(runtime.context))!
	installer := runtime.evaluate_host_value(blob_native_prototype_factory)!
	defer { runtime.release_javascript_value(installer) }
	host.prototype = runtime.retain_javascript_value(runtime.call_javascript_function(installer, C.vox_jsc_JSValueMakeUndefined(runtime.context), [resolver])!)!
	register_runtime_binding(mut blob_bindings_, owner, &host)
	runtime.add_close_handler(fn [handle, owner] () {
		mut host := unsafe { &BlobHost(handle) }
		host.close()
		unregister_runtime_binding(mut blob_bindings_, owner)
	})
}

fn (host &BlobHost) argument(args []voidptr, index int) voidptr {
	if index < args.len { return args[index] }
	return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
}

fn (host &BlobHost) record(value voidptr) !&BlobHostRecord {
	if host.closed { return error('TypeError: Blob binding is closed') }
	if record := host.by_wrapper[value] {
		if voidptr(record.host) == voidptr(host) { return record }
		return error('TypeError: Not an object of type Blob')
	}
	// A method can come from another frame, including a detached frame.
	// Recognize the actual receiver without consulting author-visible properties.
	if record := blob_record_for_context(host.runtime.context, value) { return record }
	return error('TypeError: Not an object of type Blob')
}

fn blob_record_for_context(context voidptr, value voidptr) ?&BlobHostRecord {
	if !C.JSValueIsObject(context, value) { return none }
	group := C.JSContextGetGroup(context)
	for _, host in blob_bindings_ {
		if host.closed || host.runtime.closed || host.runtime.context == unsafe { nil }
			|| C.JSContextGetGroup(host.runtime.context) != group { continue }
		if record := host.by_wrapper[value] {
			if voidptr(record.host) == voidptr(host) { return record }
		}
	}
	return none
}

fn (mut host BlobHost) wrap(blob &fileapi.Blob) !voidptr {
	if host.closed { return error('Blob binding is closed') }
	native := voidptr(blob)
	if record := host.records[native] { return record.object }
	mut record := &BlobHostRecord{ host: host, blob: blob }
	object := C.JSObjectMake(host.runtime.context, unsafe { nil }, unsafe { nil })
	C.JSObjectSetPrototype(host.runtime.context, object, host.prototype)
	record.object = host.runtime.retain_javascript_value(object)!
	host.records[native] = record
	host.by_wrapper[object] = record
	return object
}

pub fn (mut runtime Runtime) javascript_blob(blob &fileapi.Blob) !voidptr {
	mut host := blob_bindings_[voidptr(&runtime)] or { return error('Blob binding is unavailable') }
	return host.wrap(blob)
}

pub fn (runtime &Runtime) native_blob(value voidptr) !&fileapi.Blob {
	host := blob_bindings_[voidptr(runtime)] or { return error('Blob binding is unavailable') }
	return host.record(value)!.blob
}

fn (host &BlobHost) dom_string(value voidptr) !libjs.Utf16String {
	actual := host.runtime.call_javascript_function(host.to_dom_string, C.vox_jsc_JSValueMakeUndefined(host.runtime.context), [value])!
	return host.runtime.native_utf16_string(actual)
}

fn (host &BlobHost) clamped_i64(value voidptr) !i64 {
	mut exception := unsafe { nil }
	number := C.vox_jsc_JSValueToNumber(host.runtime.context, value, &exception)
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	return i64(webidl.convert_to_int(webidl.number_value(number), 64, true, .no, .yes)!)
}

fn (mut host BlobHost) operate(name string, args []voidptr) !voidptr {
	record := host.record(host.argument(args, 1))!
	blob := record.blob
	// Allocate results and queue file-reading tasks in the receiver's realm.
	// The JavaScript entrypoint converts arguments in the method's realm.
	mut owner := record.host
	realm := owner.readable.read_loop_realm()
	match name {
		'size' { return C.vox_jsc_JSValueMakeNumber(host.runtime.context, f64(blob.size())) }
		'type' { return host.runtime.javascript_utf16_string(blob.type_utf16()) }
		'slice' {
			mut start := ?i64(none)
			if !C.JSValueIsUndefined(host.runtime.context, host.argument(args, 2)) {
				start = host.clamped_i64(host.argument(args, 2))!
			}
			mut end := ?i64(none)
			if !C.JSValueIsUndefined(host.runtime.context, host.argument(args, 3)) {
				end = host.clamped_i64(host.argument(args, 3))!
			}
			mut type_ := ?string(none)
			if !C.JSValueIsUndefined(host.runtime.context, host.argument(args, 4)) {
				type_ = host.dom_string(host.argument(args, 4))!.str()
			}
			return owner.wrap(blob.slice_blob(start, end, type_))
		}
		'stream' {
			stream := owner.settings.get_blob_stream_in_realm(blob, realm)
			return owner.runtime.javascript_readable_stream(stream)
		}
		'textStream' {
			stream := owner.settings.blob_text_stream_in_realm(blob, realm)!
			return owner.runtime.javascript_readable_stream(stream)
		}
		'text' { return owner.promise(owner.settings.blob_text_in_realm(blob, realm)) }
		'arrayBuffer' { return owner.promise(owner.settings.blob_array_buffer_in_realm(blob, realm)) }
		'bytes' { return owner.promise(owner.settings.blob_bytes_in_realm(blob, realm)) }
		else { return error('TypeError: Unknown Blob operation') }
	}
}

fn (mut host BlobHost) value(value webidl.Value) !voidptr {
	if value.kind == .string_ {
		return host.runtime.javascript_utf16_string(libjs.utf16_string_from_code_units(webidl.to_utf16_string(value)!))
	}
	if value.simple_exception_ != none { return host.runtime.javascript_simple_exception(value) }
	if value.dom_exception_ != none { return host.runtime.javascript_dom_exception(value) }
	return host.runtime.actual_webidl_value(value)
}

fn (mut host BlobHost) promise(promise &webidl.Promise) !voidptr {
	handle := voidptr(&host)
	return host.runtime.javascript_webidl_promise(promise, fn [handle] (value webidl.Value) !voidptr {
		mut host := unsafe { &BlobHost(handle) }
		return host.value(value)
	})
}

const blob_native_prototype_factory = r'(function(resolve){
 const define=Object.defineProperty,create=Object.create,get=Object.getOwnPropertyDescriptor,T=TypeError,reject=Promise.reject.bind(Promise);
 const operation=self=>{const result=resolve(self);if(result===undefined)throw new T("Not an object of type Blob");return result};
 const prototype=create(Object.prototype);
 for(const name of ["size","type"]){const getter=get({get [name](){return operation(this)(name,this)}},name).get;define(prototype,name,{get:getter,enumerable:true,configurable:true})}
 const slice=({slice(){const call=operation(this),start=arguments[0]===undefined?undefined:+arguments[0],end=arguments[1]===undefined?undefined:+arguments[1],type=arguments[2]===undefined?undefined:`${arguments[2]}`;return call("slice",this,start,end,type)}}).slice;
 define(prototype,"slice",{value:slice,writable:true,enumerable:true,configurable:true});
 for(const name of ["stream","textStream"]){const method=({[name](){return operation(this)(name,this)}})[name];define(prototype,name,{value:method,writable:true,enumerable:true,configurable:true})}
 for(const name of ["text","arrayBuffer","bytes"]){const method=({[name](){try{return operation(this)(name,this)}catch(reason){return reject(reason)}}})[name];define(prototype,name,{value:method,writable:true,enumerable:true,configurable:true})}
 define(prototype,Symbol.toStringTag,{value:"Blob",configurable:true});
 return prototype;
})'
