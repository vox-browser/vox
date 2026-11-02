// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Pinned libweb_bindings/{constructors,arguments,to_idl_value}.py and
// Blob.idl: generated conversions precede Blob.cpp::process_blob_parts.
module browserjs

import fileapi
import libjs


pub fn (mut host BlobHost) install_constructor() ! {
	if host.closed || host.runtime == unsafe { nil } {
		return error('Blob native record owner is unavailable')
	}
	if host.constructor != unsafe { nil } { return }
	mut runtime := unsafe { &Runtime(host.runtime) }
	handle := voidptr(&host)
	host.buffer_kind = runtime.evaluate_host_value(blob_part_buffer_kind_intrinsic)!
	buffer := runtime.evaluate_host_value(crypto_buffer_source_intrinsics)!
	defer { runtime.release_javascript_value(buffer) }
	host.buffer_validation = runtime.retain_javascript_value(runtime.binding_property(buffer, 'validate')!)!
	host.buffer_copy = runtime.retain_javascript_value(runtime.binding_property(buffer, 'copy')!)!
	convert := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &BlobHost(handle) }
		return host.convert_part(host.argument(args, 0)) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	sequence_factory := runtime.evaluate_host_value(webidl_sequence_conversion_factory)!
	defer { runtime.release_javascript_value(sequence_factory) }
	host.parts_sequence = runtime.retain_javascript_value(runtime.call_javascript_function(sequence_factory, C.vox_jsc_JSValueMakeUndefined(runtime.context), [convert])!)!
	construct := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &BlobHost(handle) }
		return host.construct_blob(args) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	installer := runtime.evaluate_host_value(blob_native_constructor_factory)!
	defer { runtime.release_javascript_value(installer) }
	host.constructor = runtime.retain_javascript_value(runtime.call_javascript_function(installer, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		host.prototype,
		construct,
		C.JSContextGetGlobalObject(runtime.context),
	])!)!
}

fn (host &BlobHost) is_buffer_part(value voidptr) !bool {
	result := host.runtime.call_javascript_function(host.buffer_kind, C.vox_jsc_JSValueMakeUndefined(host.runtime.context), [value])!
	return C.JSValueToBoolean(host.runtime.context, result)
}

fn (mut host BlobHost) convert_part(value voidptr) !voidptr {
	if _ := host.by_wrapper[value] { return value }
	if host.is_buffer_part(value)! {
		// The union first selects the actual concrete buffer family, then its
		// generated restrictions reject shared or resizable backing records.
		host.runtime.call_javascript_function(host.buffer_validation, C.vox_jsc_JSValueMakeUndefined(host.runtime.context), [
			value,
			C.vox_jsc_JSValueMakeBoolean(host.runtime.context, true),
		])!
		return value
	}
	return host.runtime.javascript_utf16_string(host.dom_string(value)!.to_well_formed())
}

fn (mut host BlobHost) property_bag(value voidptr) !fileapi.BlobPropertyBag {
	context := host.runtime.context
	object := C.JSValueIsObject(context, value)
	if !object && !C.JSValueIsNull(context, value) && !C.JSValueIsUndefined(context, value) {
		return error('TypeError: Not an object of type BlobPropertyBag')
	}
	mut options := fileapi.BlobPropertyBag{}
	if !object { return options }
	// Pinned dictionary conversion follows the declared lexicographic order.
	endings := host.runtime.binding_property(value, 'endings')!
	if !C.JSValueIsUndefined(context, endings) {
		text := host.dom_string(endings)!
		if text.str() == 'native' {
			options.endings = .native
		} else if text.str() != 'transparent' {
			return host.ending_type_exception(text)
		}
	}
	type_ := host.runtime.binding_property(value, 'type')!
	if !C.JSValueIsUndefined(context, type_) { options.type_ = host.dom_string(type_)!.str() }
	return options
}

fn (host &BlobHost) ending_type_exception(text libjs.Utf16String) IError {
	// ErrorTypes.h::InvalidEnumerationValue formats the original UTF16 S.
	mut units := libjs.utf16_string("Invalid value '").code_units()
	units << text.code_units()
	units << libjs.utf16_string("' for enumeration type 'EndingType'").code_units()
	mut runtime := unsafe { &Runtime(host.runtime) }
	message := runtime.javascript_utf16_string(libjs.utf16_string_from_code_units(units)) or { return err }
	defer { runtime.release_javascript_value(message) }
	actual := runtime.call_engine_function(runtime.value_error_intrinsic_, [
		runtime.binding_string('TypeError'),
		message,
	]) or { return err }
	return runtime.actual_javascript_exception(actual)
}

fn (host &BlobHost) copy_part_buffer(value voidptr) ![]u8 {
	mut runtime := unsafe { &Runtime(host.runtime) }
	view := runtime.call_javascript_function(host.buffer_copy, C.vox_jsc_JSValueMakeUndefined(runtime.context), [value])!
	runtime.retain_javascript_value(view)!
	defer { runtime.release_javascript_value(view) }
	mut exception := unsafe { nil }
	length := C.vox_jsc_JSObjectGetTypedArrayByteLength(runtime.context, view, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	assert length <= uint(2147483647), 'Source Blob ByteBuffer exceeds the V span'
	mut bytes := []u8{len: int(length)}
	if length > 0 {
		pointer := C.vox_jsc_JSObjectGetTypedArrayBytesPtr(runtime.context, view, &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		unsafe { C.memcpy(bytes.data, pointer, length) }
	}
	return bytes
}

fn (mut host BlobHost) converted_parts(sequence voidptr) ![]fileapi.BlobPart {
	length_value := host.runtime.binding_property(sequence, 'length')!
	mut exception := unsafe { nil }
	length := C.vox_jsc_JSValueToNumber(host.runtime.context, length_value, &exception)
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	mut parts := []fileapi.BlobPart{cap: int(length)}
	for index in 0 .. int(length) {
		value := C.vox_jsc_JSObjectGetPropertyAtIndex(host.runtime.context, sequence, u32(index), &exception)
		if exception != unsafe { nil } {
			return host.runtime.actual_javascript_exception(exception)
		}
		if record := host.by_wrapper[value] {
			parts << fileapi.BlobPart.from_blob(record.blob)
		} else if C.JSValueIsString(host.runtime.context, value) {
			parts << fileapi.BlobPart.from_string(host.runtime.native_utf16_string(value)!.str())
		} else {
			// Source copies BufferSource data in process_blob_parts after all
			// conversions and option getters, retaining mutations/detachment.
			parts << fileapi.BlobPart.from_bytes(host.copy_part_buffer(value)!)
		}
	}
	return parts
}

fn (mut host BlobHost) construct_blob(args []voidptr) !voidptr {
	if host.closed { return error('TypeError: Blob binding is closed') }
	parts_value := host.argument(args, 1)
	mut sequence := unsafe { nil }
	if !C.JSValueIsUndefined(host.runtime.context, parts_value) {
		sequence = host.runtime.call_javascript_function(host.parts_sequence, C.vox_jsc_JSValueMakeUndefined(host.runtime.context), [parts_value])!
		host.runtime.retain_javascript_value(sequence)!
	}
	defer { if sequence != unsafe { nil } { host.runtime.release_javascript_value(sequence) } }
	options := host.property_bag(host.argument(args, 2))!
	mut parts := ?[]fileapi.BlobPart(none)
	if sequence != unsafe { nil } { parts = host.converted_parts(sequence)! }
	blob := fileapi.Blob.construct_impl(parts, options)
	object := host.wrap(blob)!
	C.JSObjectSetPrototype(host.runtime.context, object, host.argument(args, 0))
	return object
}

const blob_part_buffer_kind_intrinsic = r'(function(){
 const apply=Reflect.apply,isView=ArrayBuffer.isView,get=Object.getOwnPropertyDescriptor,length=get(ArrayBuffer.prototype,"byteLength").get;
 return function(value){if(isView(value))return true;try{apply(length,value,[]);return true}catch(ignore){return false}};
})()'

const blob_native_constructor_factory = r'(function(prototype,construct,global){
 "use strict";
 const define=Object.defineProperty,T=TypeError,P=Proxy;
 const Blob=new P(function Blob(){throw new T("Blob constructor must be called with \u0027new\u0027")},{construct(target,args,newTarget){let selected=newTarget.prototype;if(selected===null||(typeof selected!=="object"&&typeof selected!=="function"))selected=prototype;return construct(selected,args[0],args[1])}});
 define(Blob,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:Blob,writable:true,configurable:true});
 define(global,"Blob",{value:Blob,writable:true,configurable:true});
 return Blob;
})'
