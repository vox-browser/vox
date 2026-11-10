// Copyright (c) 2021-2022, Linus Groh <linusg@serenityos.org>
// Copyright (c) 2023-2024, stelar7 <dudedbz@gmail.com>
// Copyright (c) 2024, Jelle Raaijmakers <jelle@ladybird.org>
// Copyright (c) 2024, Andrew Kaster <akaster@serenityos.org>
// Copyright (c) 2024, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2024-2025, Altomani Gianluca <altomanigianluca@gmail.com>
// Copyright (c) 2026, Ladybird contributors
// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// SubtleCrypto.cpp generateKey, CryptoAlgorithms.cpp parameters, and pinned
// Meta/Generators/libweb_bindings/to_idl_value.py sequence/enum conversion.
module browserjs

import webcrypto
import webidl


const crypto_native_usages = [webcrypto.KeyUsage.encrypt, .decrypt, .sign, .verify, .derive_key,
	.derive_bits, .wrap_key, .unwrap_key, .encapsulate_key, .encapsulate_bits, .decapsulate_key,
	.decapsulate_bits]

fn (mut host CryptoHost) install_generate_key() ! {
	mut runtime := unsafe { &Runtime(host.runtime) }
	handle := voidptr(&host)
	convert := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		host := unsafe { &CryptoHost(handle) }
		name := host.algorithm_string(host.argument(args, 0)) or { return host.exception(err) }
		for index, usage in crypto_native_usages {
			if name == webcrypto.key_usage_to_string(usage) {
				return C.vox_jsc_JSValueMakeNumber(host.runtime.context, index)
			}
		}
		return host.exception(error("TypeError: Invalid value '${name}' for enumeration type 'KeyUsage'"))
	})!
	sequence := runtime.evaluate_host_value(webidl_sequence_conversion_factory)!
	defer { runtime.release_javascript_value(sequence) }
	host.usage_sequence = runtime.retain_javascript_value(runtime.call_javascript_function(sequence, C.vox_jsc_JSValueMakeUndefined(runtime.context), [convert])!)!
	generate := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &CryptoHost(handle) }
		native := host.generate_key_operation(args) or { return host.rejected_crypto_promise(err) }
		return host.crypto_promise(native)
	})!
	installer := runtime.evaluate_host_value(r'(function(prototype,generate){Object.defineProperty(prototype,"generateKey",{value:function generateKey(algorithm,extractable,keyUsages){return arguments.length<3?generate(this):generate(this,algorithm,extractable,keyUsages)},writable:true,enumerable:true,configurable:true})})')!
	defer { runtime.release_javascript_value(installer) }
	prototype := host.prototypes[.subtle] or { return error('SubtleCrypto prototype unavailable') }
	runtime.call_javascript_function(installer, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		prototype,
		generate,
	])!
}

fn (host &CryptoHost) convert_crypto_usages(value voidptr) ![]webcrypto.KeyUsage {
	mut runtime := unsafe { &Runtime(host.runtime) }
	sequence := runtime.call_javascript_function(host.usage_sequence, C.vox_jsc_JSValueMakeUndefined(runtime.context), [value])!
	runtime.retain_javascript_value(sequence)!
	defer { runtime.release_javascript_value(sequence) }
	mut exception := unsafe { nil }
	length := C.vox_jsc_JSValueToNumber(runtime.context, runtime.binding_property(sequence, 'length')!, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	mut result := []webcrypto.KeyUsage{cap: int(length)}
	for index in 0 .. int(length) {
		item := C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, sequence, u32(index), &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		id := int(C.vox_jsc_JSValueToNumber(runtime.context, item, &exception))
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		result << crypto_native_usages[id]
	}
	return result
}

fn (host &CryptoHost) crypto_hash_identifier(value voidptr) !webidl.Value {
	if C.JSValueIsUndefined(host.runtime.context, value) {
		return error('TypeError: hash is required')
	}
	// AlgorithmIdentifier uses DOMString conversion for non-object values.
	return host.normalize_digest(value, C.JSValueIsObject(host.runtime.context, value))
}

fn (host &CryptoHost) generation_uint(dictionary voidptr, field string, width int) !webidl.Value {
	value := host.runtime.binding_property(dictionary, field)!
	number := host.algorithm_number(value)!
	return webidl.number_value(webidl.convert_to_int(webidl.number_value(number), width, false, .yes, .no)!)
}

fn (host &CryptoHost) normalize_generation(value voidptr, is_object bool) !webidl.Value {
	mut runtime := unsafe { &Runtime(host.runtime) }
	dictionary := host.algorithm_dictionary(value, is_object)!
	runtime.retain_javascript_value(dictionary)!
	defer { runtime.release_javascript_value(dictionary) }
	initial_name := runtime.binding_property(dictionary, 'name')!
	if C.JSValueIsUndefined(runtime.context, initial_name) {
		return error('TypeError: Not an object of type Algorithm')
	}
	name := webcrypto.normalize_an_algorithm(host.algorithm_string(initial_name)!, 'generateKey')!
	mut normalized := {
		'name': webidl.string_value(name)
	}
	if name.starts_with('AES-') {
		normalized['length'] = host.generation_uint(dictionary, 'length', 16)!
	} else if name in ['HMAC', 'KMAC128', 'KMAC256'] {
		if name == 'HMAC' {
			normalized['hash'] = host.crypto_hash_identifier(runtime.binding_property(dictionary, 'hash')!)!
		}
		if host.algorithm_has(dictionary, 'length')! {
			normalized['length'] = host.generation_uint(dictionary, 'length', 32)!
		}
	} else if name in ['ECDSA', 'ECDH'] {
		normalized['namedCurve'] = webidl.string_value(host.algorithm_string(runtime.binding_property(dictionary, 'namedCurve')!)!)
	} else if name in ['RSA-OAEP', 'RSA-PSS', 'RSASSA-PKCS1-v1_5'] {
		normalized['modulusLength'] = host.generation_uint(dictionary, 'modulusLength', 32)!
		exponent := runtime.binding_property(dictionary, 'publicExponent')!
		mut exception := unsafe { nil }
		kind := C.vox_jsc_crypto_integer_view_kind(runtime.context, exponent, &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		if kind != 1 { return error('TypeError: Not an object of type Uint8Array') }
		runtime.retain_javascript_value(exponent)!
		defer { runtime.release_javascript_value(exponent) }
		normalized['hash'] = host.crypto_hash_identifier(runtime.binding_property(dictionary, 'hash')!)!
		// Source reads the exponent span after the hash normalization, so hash
		// getters may mutate it before its conversion to an unsigned integer.
		source := host.copy_crypto_buffer(exponent)!
		bytes := webidl.get_buffer_source_copy(source)
		normalized['publicExponent'] = webidl.buffer_source_value(webidl.BufferSource.view(.uint8_array, bytes, 0, u32(bytes.len))!)
	}
	return webidl.object_value(normalized)
}

fn (mut host CryptoHost) generate_key_operation(args []voidptr) !&webidl.Promise {
	host.record(host.argument(args, 0), .subtle)!
	if args.len < 4 { return error('TypeError: generateKey() needs 3 arguments') }
	algorithm := args[1]
	is_object := C.JSValueIsObject(host.runtime.context, algorithm)
	mut converted := unsafe { algorithm }
	if !is_object { converted = host.runtime.binding_string(host.algorithm_string(algorithm)!) }
	host.runtime.retain_javascript_value(converted)!
	defer { host.runtime.release_javascript_value(converted) }
	extractable := C.JSValueToBoolean(host.runtime.context, args[2])
	usages := host.convert_crypto_usages(args[3])!
	normalized := host.normalize_generation(converted, is_object)!
	return host.service.subtle().generate_key(normalized, extractable, usages)
}
