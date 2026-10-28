// Copyright (c) 2021-2022, Linus Groh <linusg@serenityos.org>
// Copyright (c) 2023-2024, stelar7 <dudedbz@gmail.com>
// Copyright (c) 2024, Jelle Raaijmakers <jelle@ladybird.org>
// Copyright (c) 2024, Andrew Kaster <akaster@serenityos.org>
// Copyright (c) 2024, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2024-2025, Altomani Gianluca <altomanigianluca@gmail.com>
// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// Source importKey bindings, algorithm parameter bodies and generated dictionaries.
module browserjs

import webcrypto
import webidl


const crypto_jwk_members = ['alg', 'crv', 'd', 'dp', 'dq', 'e', 'ext', 'k', 'key_ops', 'kty', 'n',
	'oth', 'p', 'priv', 'pub', 'q', 'qi', 'use', 'x', 'y']

fn (mut host CryptoHost) install_import_key() ! {
	mut runtime := unsafe { &Runtime(host.runtime) }
	handle := voidptr(&host)
	strings := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		host := unsafe { &CryptoHost(handle) }
		value := host.algorithm_string(host.argument(args, 0)) or { return host.exception(err) }
		return host.runtime.binding_string(value)
	})!
	primes := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &CryptoHost(handle) }
		value := host.convert_jwk_dictionary(host.argument(args, 0), true) or { return host.exception(err) }
		mut properties := value.object_value.clone()
		// Internal sequence results shadow inherited getters for absent fields;
		// only the first conversion below can consult author dictionary values.
		for name in ['d', 'r', 't'] {
			if name !in properties { properties[name] = webidl.undefined_value() }
		}
		return host.crypto_object(webidl.object_value(properties)) or { return host.exception(err) }
	})!
	sequence := runtime.evaluate_host_value(webidl_sequence_conversion_factory)!
	defer { runtime.release_javascript_value(sequence) }
	host.string_sequence = runtime.retain_javascript_value(runtime.call_javascript_function(sequence, C.JSValueMakeUndefined(runtime.context), [strings])!)!
	host.prime_sequence = runtime.retain_javascript_value(runtime.call_javascript_function(sequence, C.JSValueMakeUndefined(runtime.context), [primes])!)!
	host.buffer_is_array = runtime.evaluate_host_value(r'(function(){const apply=Reflect.apply,get=Object.getOwnPropertyDescriptor(ArrayBuffer.prototype,"byteLength").get;return function(value){try{apply(get,value,[]);return true}catch(error){return false}}})()')!
	import_key := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &CryptoHost(handle) }
		native := host.import_key_operation(args) or { return host.rejected_crypto_promise(err) }
		return host.crypto_promise(native)
	})!
	installer := runtime.evaluate_host_value(r'(function(prototype,operate){Object.defineProperty(prototype,"importKey",{value:function importKey(format,keyData,algorithm,extractable,keyUsages){return arguments.length<5?operate(this):operate(this,format,keyData,algorithm,extractable,keyUsages)},writable:true,enumerable:true,configurable:true})})')!
	defer { runtime.release_javascript_value(installer) }
	prototype := host.prototypes[.subtle] or { return error('SubtleCrypto prototype unavailable') }
	runtime.call_javascript_function(installer, C.JSValueMakeUndefined(runtime.context), [
		prototype,
		import_key,
	])!
}

fn (host &CryptoHost) import_data_is_buffer(value voidptr) !bool {
	view := host.runtime.call_javascript_function(host.array_is_view, C.JSValueMakeUndefined(host.runtime.context), [value])!
	if C.JSValueToBoolean(host.runtime.context, view) { return true }
	array := host.runtime.call_javascript_function(host.buffer_is_array, C.JSValueMakeUndefined(host.runtime.context), [value])!
	return C.JSValueToBoolean(host.runtime.context, array)
}

fn (mut host CryptoHost) convert_jwk_sequence(value voidptr, primes bool) !webidl.Value {
	mut runtime := unsafe { &Runtime(host.runtime) }
	mut converter := host.string_sequence
	if primes { converter = host.prime_sequence }
	sequence := runtime.call_javascript_function(converter, C.JSValueMakeUndefined(runtime.context), [value])!
	runtime.retain_javascript_value(sequence)!
	defer { runtime.release_javascript_value(sequence) }
	mut exception := unsafe { nil }
	length := int(C.JSValueToNumber(runtime.context, runtime.binding_property(sequence, 'length')!, &exception))
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	mut result := []webidl.Value{cap: length}
	for index in 0 .. length {
		item := C.JSObjectGetPropertyAtIndex(runtime.context, sequence, u32(index), &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		if primes {
			mut dictionary := map[string]webidl.Value{}
			for name in ['d', 'r', 't'] {
				property := runtime.binding_property(item, name)!
				if !C.JSValueIsUndefined(runtime.context, property) {
					dictionary[name] = webidl.string_value(runtime.binding_dom_string(property)!)
				}
			}
			result << webidl.object_value(dictionary)
		} else {
			result << webidl.string_value(runtime.binding_dom_string(item)!)
		}
	}
	return webidl.sequence_value(result)
}

fn (mut host CryptoHost) convert_jwk_dictionary(value voidptr, prime bool) !webidl.Value {
	mut runtime := unsafe { &Runtime(host.runtime) }
	is_object := C.JSValueIsObject(runtime.context, value)
	if !is_object && !C.JSValueIsNull(runtime.context, value) && !C.JSValueIsUndefined(runtime.context, value) {
		name := if prime { 'RsaOtherPrimesInfo' } else { 'JsonWebKey' }
		return error('TypeError: Not an object of type ${name}')
	}
	mut dictionary := map[string]webidl.Value{}
	if !is_object { return webidl.object_value(dictionary) }
	members := if prime { ['d', 'r', 't'] } else { crypto_jwk_members }
	for name in members {
		property := runtime.binding_property(value, name)!
		if C.JSValueIsUndefined(runtime.context, property) { continue }
		if name == 'ext' {
			dictionary[name] = webidl.boolean_value(C.JSValueToBoolean(runtime.context, property))
		} else if name in ['key_ops', 'oth'] {
			dictionary[name] = host.convert_jwk_sequence(property, name == 'oth')!
		} else {
			dictionary[name] = webidl.string_value(host.algorithm_string(property)!)
		}
	}
	return webidl.object_value(dictionary)
}

fn (host &CryptoHost) normalize_import(value voidptr, is_object bool) !webidl.Value {
	return host.normalize_import_for_operation(value, is_object, 'importKey')
}

fn (host &CryptoHost) normalize_import_for_operation(value voidptr, is_object bool, operation string) !webidl.Value {
	mut runtime := unsafe { &Runtime(host.runtime) }
	dictionary := host.algorithm_dictionary(value, is_object)!
	runtime.retain_javascript_value(dictionary)!
	defer { runtime.release_javascript_value(dictionary) }
	initial_name := runtime.binding_property(dictionary, 'name')!
	if C.JSValueIsUndefined(runtime.context, initial_name) {
		return error('TypeError: Not an object of type Algorithm')
	}
	name := webcrypto.normalize_an_algorithm(host.algorithm_string(initial_name)!, operation)!
	mut normalized := {
		'name': webidl.string_value(name)
	}
	if operation == 'get key length' && name.starts_with('AES-') {
		normalized['length'] = host.generation_uint(dictionary, 'length', 16)!
	}
	if name == 'HMAC' || name in ['RSA-OAEP', 'RSA-PSS', 'RSASSA-PKCS1-v1_5'] {
		normalized['hash'] = host.crypto_hash_identifier(runtime.binding_property(dictionary, 'hash')!)!
	}
	if name in ['HMAC', 'KMAC128', 'KMAC256'] && host.algorithm_has(dictionary, 'length')! {
		normalized['length'] = host.generation_uint(dictionary, 'length', 32)!
	} else if name in ['ECDSA', 'ECDH'] {
		normalized['namedCurve'] = webidl.string_value(host.algorithm_string(runtime.binding_property(dictionary, 'namedCurve')!)!)
	}
	return webidl.object_value(normalized)
}

fn (mut host CryptoHost) import_key_operation(args []voidptr) !&webidl.Promise {
	host.record(host.argument(args, 0), .subtle)!
	if args.len < 6 { return error('TypeError: importKey() needs 5 arguments') }
	format := host.convert_key_format(args[1])!
	buffer := host.import_data_is_buffer(args[2])!
	mut material := webidl.undefined_value()
	if buffer {
		host.validate_crypto_buffer(args[2], true)!
	} else {
		if !C.JSValueIsObject(host.runtime.context, args[2]) && !C.JSValueIsNull(host.runtime.context, args[2]) && !C.JSValueIsUndefined(host.runtime.context, args[2]) {
			return error('TypeError: No union types matched')
		}
		material = host.convert_jwk_dictionary(args[2], false)!
	}
	algorithm := args[3]
	is_object := C.JSValueIsObject(host.runtime.context, algorithm)
	mut converted := unsafe { algorithm }
	if !is_object { converted = host.runtime.binding_string(host.algorithm_string(algorithm)!) }
	host.runtime.retain_javascript_value(converted)!
	defer { host.runtime.release_javascript_value(converted) }
	extractable := C.JSValueToBoolean(host.runtime.context, args[4])
	usages := host.convert_crypto_usages(args[5])!
	// The ImplementedInBindings format/union check follows every IDL argument
	// conversion. Raw SharedArrayBuffer follows the pinned dictionary fallback.
	if webcrypto.key_format_expects_buffer_source(format) && !buffer {
		return error('TypeError: Not an object of type BufferSource')
	}
	if format == .jwk && buffer { return error('TypeError: Not an object of type JsonWebKey') }
	if buffer { material = webidl.buffer_source_value(host.copy_crypto_buffer(args[2])!) }
	// Import copies bytes before algorithm getters. Unlike digest normalization,
	// those getters cannot subsequently change the imported material.
	normalized := host.normalize_import(converted, is_object)!
	return host.service.subtle().import_key(format, material, normalized, extractable, usages)
}
