// Copyright (c) 2021-2022, Linus Groh <linusg@serenityos.org>
// Copyright (c) 2023-2024, stelar7 <dudedbz@gmail.com>
// Copyright (c) 2024, Jelle Raaijmakers <jelle@ladybird.org>
// Copyright (c) 2024, Andrew Kaster <akaster@serenityos.org>
// Copyright (c) 2024, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2024-2025, Altomani Gianluca <altomanigianluca@gmail.com>
// Copyright (c) 2021-2023, Luke Wilde <lukew@serenityos.org>
// Copyright (c) 2023, Shannon Booth <shannon@serenityos.org>
// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// SubtleCrypto.cpp digest and generated Promise-returning IDL binding.
module browserjs

import webcrypto
import webidl


fn (mut host CryptoHost) install_digest() ! {
	mut runtime := unsafe { &Runtime(host.runtime) }
	host.to_dom_string = runtime.evaluate_host_value(r'(function(value){return `${value}`})')!
	host.to_number = runtime.evaluate_host_value('(function(value){return +value})')!
	host.has_property = runtime.evaluate_host_value('Reflect.has')!
	intrinsics := runtime.evaluate_host_value(crypto_buffer_source_intrinsics)!
	defer { runtime.release_javascript_value(intrinsics) }
	host.buffer_validation = runtime.retain_javascript_value(runtime.binding_property(intrinsics, 'validate')!)!
	host.buffer_copy = runtime.retain_javascript_value(runtime.binding_property(intrinsics, 'copy')!)!
	handle := voidptr(&host)
	digest := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &CryptoHost(handle) }
		// Generated bindings turn receiver/argument/conversion exceptions into
		// a Promise rejection, including the original author-thrown value.
		native := host.digest_operation(args) or { return host.rejected_crypto_promise(err) }
		return host.crypto_promise(native)
	})!
	installer := runtime.evaluate_host_value(r'(function(prototype,digestNative){Object.defineProperty(prototype,"digest",{value:function digest(algorithm,data){return arguments.length<2?digestNative(this):digestNative(this,algorithm,data)},writable:true,enumerable:true,configurable:true})})')!
	defer { runtime.release_javascript_value(installer) }
	prototype := host.prototypes[.subtle] or { return error('SubtleCrypto prototype unavailable') }
	runtime.call_javascript_function(installer, C.JSValueMakeUndefined(runtime.context), [
		prototype,
		digest,
	])!
}

fn (host &CryptoHost) algorithm_string(value voidptr) !string {
	actual := host.runtime.call_javascript_function(host.to_dom_string, C.JSValueMakeUndefined(host.runtime.context), [value])!
	return host.runtime.binding_dom_string(actual)
}

fn (host &CryptoHost) algorithm_number(value voidptr) !f64 {
	actual := host.runtime.call_javascript_function(host.to_number, C.JSValueMakeUndefined(host.runtime.context), [value])!
	mut exception := unsafe { nil }
	result := C.JSValueToNumber(host.runtime.context, actual, &exception)
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	return result
}

fn (host &CryptoHost) algorithm_has(object voidptr, name string) !bool {
	actual := host.runtime.call_javascript_function(host.has_property, C.JSValueMakeUndefined(host.runtime.context), [
		object,
		host.runtime.binding_string(name),
	])!
	return C.JSValueToBoolean(host.runtime.context, actual)
}

fn (host &CryptoHost) validate_crypto_buffer(value voidptr, binding_restrictions bool) ! {
	host.runtime.call_javascript_function(host.buffer_validation, C.JSValueMakeUndefined(host.runtime.context), [
		value,
		C.JSValueMakeBoolean(host.runtime.context, binding_restrictions),
	])!
}

fn (host &CryptoHost) copy_crypto_buffer(value voidptr) !webidl.BufferSource {
	// Captured builtins use internal view slots, rather than author properties.
	// The copy operation returns a zero-offset engine-owned byte view. JSC
	// supplies the shared-buffer reads; native code only copies its result.
	mut runtime := unsafe { &Runtime(host.runtime) }
	view := runtime.call_javascript_function(host.buffer_copy, C.JSValueMakeUndefined(runtime.context), [value])!
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
	return webidl.BufferSource.array_buffer(bytes)
}

fn (host &CryptoHost) normalize_digest(value voidptr, is_object bool) !webidl.Value {
	mut runtime := unsafe { &Runtime(host.runtime) }
	dictionary := host.algorithm_dictionary(value, is_object)!
	runtime.retain_javascript_value(dictionary)!
	defer { runtime.release_javascript_value(dictionary) }
	initial_name := runtime.binding_property(dictionary, 'name')!
	if C.JSValueIsUndefined(runtime.context, initial_name) {
		return error('TypeError: Not an object of type Algorithm')
	}
	name := host.algorithm_string(initial_name)!
	canonical := webcrypto.normalize_an_algorithm(name, 'digest')!
	mut normalized := {
		'name': webidl.string_value(canonical)
	}
	if canonical in ['cSHAKE128', 'cSHAKE256'] {
		if !host.algorithm_has(dictionary, 'outputLength')! {
			return error('TypeError: Required property outputLength is missing or undefined')
		}
		length_value := runtime.binding_property(dictionary, 'outputLength')!
		length := webidl.convert_to_int(webidl.number_value(host.algorithm_number(length_value)!), 32, false, .yes, .no)!
		normalized['outputLength'] = webidl.number_value(length)
		for field in ['functionName', 'customization'] {
			if host.algorithm_has(dictionary, field)! {
				buffer := runtime.binding_property(dictionary, field)!
				// Algorithm parameter bodies use is_buffer_source_type, without
				// the generated top-level IDL shared/resizable restrictions.
				host.validate_crypto_buffer(buffer, false)!
				normalized[field] = webidl.buffer_source_value(host.copy_crypto_buffer(buffer)!)
			}
		}
	}
	return webidl.object_value(normalized)
}

fn (mut host CryptoHost) digest_operation(args []voidptr) !&webidl.Promise {
	host.record(host.argument(args, 0), .subtle)!
	if args.len < 3 { return error('TypeError: digest() needs 2 arguments') }
	algorithm := args[1]
	is_object := C.JSValueIsObject(host.runtime.context, algorithm)
	mut converted := unsafe { algorithm }
	// AlgorithmIdentifier's primitive DOMString conversion precedes the data
	// argument conversion. Object.name is read in the operation body instead.
	if !is_object { converted = host.runtime.binding_string(host.algorithm_string(algorithm)!) }
	host.runtime.retain_javascript_value(converted)!
	defer { host.runtime.release_javascript_value(converted) }
	host.validate_crypto_buffer(args[2], true)!
	normalized := host.normalize_digest(converted, is_object)!
	// Source normalization may run author getters which mutate/detach data.
	data := host.copy_crypto_buffer(args[2])!
	return host.service.subtle().digest(normalized, data)
}

fn (mut host CryptoHost) rejected_crypto_promise(reason IError) !voidptr {
	actual := host.runtime.binding_exception_value(host.exception(reason))
	native := webidl.create_rejected_promise_for(host.settings.stream_promise_context(), host.runtime.webidl_value(actual)!)
	return host.crypto_promise(native)
}

fn (mut host CryptoHost) crypto_promise(native &webidl.Promise) !voidptr {
	handle := voidptr(&host)
	return host.runtime.javascript_webidl_promise(native, fn [handle] (value webidl.Value) !voidptr {
		mut host := unsafe { &CryptoHost(handle) }
		return host.crypto_value(value)
	})
}

fn (mut host CryptoHost) crypto_value(value webidl.Value) !voidptr {
	mut runtime := unsafe { &Runtime(host.runtime) }
	if value.kind == .runtime_value { return runtime.actual_webidl_value(value) }
	if value.kind == .undefined { return C.JSValueMakeUndefined(runtime.context) }
	if value.kind == .null_ { return C.JSValueMakeNull(runtime.context) }
	if value.kind == .boolean { return C.JSValueMakeBoolean(runtime.context, value.boolean_value) }
	if value.kind == .number { return C.JSValueMakeNumber(runtime.context, value.number_value) }
	if value.kind == .string_ { return runtime.binding_utf16_string(value.string_utf16()) }
	if _ := value.dom_exception_ { return runtime.javascript_dom_exception(value) }
	if value.kind == .platform_object { return host.wrap_crypto_key(webcrypto.crypto_key_from_value(value)!) }
	if value.kind == .buffer_source {
		source := value.buffer_value or { return error('Missing native Crypto buffer') }
		bytes := webidl.get_buffer_source_copy(source)
		mut exception := unsafe { nil }
		view := C.JSObjectMakeTypedArray(runtime.context, C.kJSTypedArrayTypeUint8Array, uint(bytes.len), &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		runtime.retain_javascript_value(view)!
		defer { runtime.release_javascript_value(view) }
		if bytes.len > 0 {
			pointer := C.JSObjectGetTypedArrayBytesPtr(runtime.context, view, &exception)
			if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
			unsafe { C.memcpy(pointer, bytes.data, uint(bytes.len)) }
		}
		if source.kind == .uint8_array { return view }
		buffer := C.JSObjectGetTypedArrayBuffer(runtime.context, view, &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		return buffer
	}
	if value.kind == .object {
		if message := value.object_value['message'] {
			name := (value.object_value['name'] or { webidl.undefined_value() }).string_value
			if name in ['TypeError', 'RangeError', 'InternalError'] {
				return runtime.binding_exception_value(error('${name}: ${message.string_value}'))
			}
		}
		return host.crypto_object(value)
	}
	if value.kind == .sequence { return host.crypto_object(value) }
	return error('Value is outside the installed Crypto binding conversions')
}

// WebIDL::get_buffer_source_copy uses witnesses before offset/length and returns
// empty bytes for detached/out-of-bounds input. All consulted operations below
// are engine intrinsics captured before any author script runs. TypeError
// recognition uses the captured default brand check, bypassing author hooks.
const crypto_buffer_source_intrinsics = r'(function(){
 const apply=Reflect.apply,get=Object.getOwnPropertyDescriptor,T=TypeError,hasInstance=Function.prototype[Symbol.hasInstance],U8=Uint8Array,ab=get(ArrayBuffer.prototype,"byteLength").get,r=get(ArrayBuffer.prototype,"resizable"),tp=Object.getPrototypeOf(Int8Array.prototype),tb=get(tp,"buffer").get,to=get(tp,"byteOffset").get,tl=get(tp,"byteLength").get,tag=get(tp,Symbol.toStringTag).get,values=Int8Array.prototype.values,db=get(DataView.prototype,"buffer").get,dl=get(DataView.prototype,"byteLength").get,doff=get(DataView.prototype,"byteOffset").get,sab=typeof SharedArrayBuffer==="function"?get(SharedArrayBuffer.prototype,"byteLength").get:null;
 function describe(value,restrict){let buffer,type;try{buffer=apply(tb,value,[]);type=apply(tag,value,[])}catch(error){try{buffer=apply(db,value,[]);type="DataView"}catch(error){try{apply(ab,value,[]);buffer=value;type="ArrayBuffer"}catch(error){if(sab){try{apply(sab,value,[]);buffer=value;type="ArrayBuffer"}catch(error){}}}}}if(!buffer)throw new T(restrict?"No union types matched":"Not an object of type BufferSource");return {buffer,type}}
 return {validate(value,restrict){const d=describe(value,restrict);if(restrict){if(sab){try{apply(sab,d.buffer,[]);throw "shared"}catch(error){if(error==="shared")throw new T(d.type==="ArrayBuffer"?"No union types matched":"The array buffer object cannot be a SharedArrayBuffer")}}if(r&&apply(r.get,d.buffer,[]))throw new T("Not an object of type fixed-length "+d.type)}},copy(value){const d=describe(value,false);let offset=0,length=0;if(d.type==="DataView"){try{length=apply(dl,value,[]);offset=apply(doff,value,[])}catch(error){return new U8(0)}}else if(d.type!=="ArrayBuffer"){try{apply(values,value,[])}catch(error){return new U8(0)}length=apply(tl,value,[]);offset=apply(to,value,[])}else{try{length=apply(ab,d.buffer,[])}catch(error){length=apply(sab,d.buffer,[])}}let span;try{span=new U8(d.buffer,offset,length)}catch(error){if(apply(hasInstance,T,[error]))return new U8(0);throw error}return new U8(span)}}
})()'
