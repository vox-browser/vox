// Copyright (c) 2021-2022, Linus Groh <linusg@serenityos.org>
// Copyright (c) 2023-2024, stelar7 <dudedbz@gmail.com>
// Copyright (c) 2024, Jelle Raaijmakers <jelle@ladybird.org>
// Copyright (c) 2024, Andrew Kaster <akaster@serenityos.org>
// Copyright (c) 2024, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2024-2025, Altomani Gianluca <altomanigianluca@gmail.com>
// SPDX-License-Identifier: BSD-2-Clause
// Source deriveBits/deriveKey and CryptoAlgorithms.cpp parameter conversions.
module browserjs

import webcrypto
import webidl


fn (mut host CryptoHost) install_derivation_operations() ! {
	mut runtime := unsafe { &Runtime(host.runtime) }
	handle := voidptr(&host)
	operate := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &CryptoHost(handle) }
		native := host.derivation_operation(args) or { return host.rejected_crypto_promise(err) }
		return host.crypto_promise(native)
	})!
	installer := runtime.evaluate_host_value(r'(function(prototype,operate){const define=Object.defineProperty;define(prototype,"deriveBits",{value:function deriveBits(algorithm,baseKey){return arguments.length<2?operate("deriveBits",this):arguments.length<3?operate("deriveBits",this,algorithm,baseKey):operate("deriveBits",this,algorithm,baseKey,arguments[2])},writable:true,enumerable:true,configurable:true});define(prototype,"deriveKey",{value:function deriveKey(algorithm,baseKey,derivedKeyType,extractable,keyUsages){return arguments.length<5?operate("deriveKey",this):operate("deriveKey",this,algorithm,baseKey,derivedKeyType,extractable,keyUsages)},writable:true,enumerable:true,configurable:true})})')!
	defer { runtime.release_javascript_value(installer) }
	prototype := host.prototypes[.subtle] or { return error('SubtleCrypto prototype unavailable') }
	runtime.call_javascript_function(installer, C.JSValueMakeUndefined(runtime.context), [
		prototype,
		operate,
	])!
}

fn (host &CryptoHost) crypto_enforced_parameter(dictionary voidptr, name string, width int, required bool) !webidl.Value {
	if required && !host.algorithm_has(dictionary, name)! {
		return error('TypeError: Required property ${name} is missing or undefined')
	}
	value := host.runtime.binding_property(dictionary, name)!
	return webidl.number_value(webidl.convert_to_int(webidl.number_value(host.algorithm_number(value)!), width, false, .yes, .no)!)
}

fn (host &CryptoHost) normalize_derivation(value voidptr, is_object bool) !webidl.Value {
	mut runtime := unsafe { &Runtime(host.runtime) }
	dictionary := host.algorithm_dictionary(value, is_object)!
	runtime.retain_javascript_value(dictionary)!
	defer { runtime.release_javascript_value(dictionary) }
	initial_name := runtime.binding_property(dictionary, 'name')!
	if C.JSValueIsUndefined(runtime.context, initial_name) {
		return error('TypeError: Not an object of type Algorithm')
	}
	name := webcrypto.normalize_an_algorithm(host.algorithm_string(initial_name)!, 'deriveBits')!
	mut normalized := {
		'name': webidl.string_value(name)
	}
	if name == 'HKDF' {
		normalized['hash'] = host.crypto_hash_identifier(runtime.binding_property(dictionary, 'hash')!)!
		normalized['salt'] = host.crypto_parameter_buffer(dictionary, 'salt')!
		normalized['info'] = host.crypto_parameter_buffer(dictionary, 'info')!
	} else if name == 'PBKDF2' {
		normalized['salt'] = host.crypto_parameter_buffer(dictionary, 'salt')!
		normalized['iterations'] = host.generation_uint(dictionary, 'iterations', 32)!
		normalized['hash'] = host.crypto_hash_identifier(runtime.binding_property(dictionary, 'hash')!)!
	} else if name in ['Argon2d', 'Argon2i', 'Argon2id'] {
		if !host.algorithm_has(dictionary, 'nonce')! {
			return error('TypeError: Required property nonce is missing or undefined')
		}
		normalized['nonce'] = host.crypto_parameter_buffer(dictionary, 'nonce')!
		for field in ['parallelism', 'memory', 'passes'] {
			normalized[field] = host.crypto_enforced_parameter(dictionary, field, 32, true)!
		}
		if host.algorithm_has(dictionary, 'version')! {
			normalized['version'] = host.crypto_enforced_parameter(dictionary, 'version', 8, false)!
		}
		for field in ['secretValue', 'associatedData'] {
			if host.algorithm_has(dictionary, field)! {
				normalized[field] = host.crypto_parameter_buffer(dictionary, field)!
			}
		}
	} else {
		public := runtime.binding_property(dictionary, 'public')!
		// Source crypto_key_from_value first applies ToObject, then the brand.
		if C.JSValueIsNull(runtime.context, public) || C.JSValueIsUndefined(runtime.context, public) {
			return error('TypeError: ToObject on null or undefined')
		}
		record := host.record(public, .key)!
		key := unsafe { &webcrypto.CryptoKey(record.native) }
		normalized['public'] = webcrypto.crypto_key(u64(voidptr(host.settings.realm())).str(), key)
	}
	return webidl.object_value(normalized)
}

fn (mut host CryptoHost) derivation_operation(args []voidptr) !&webidl.Promise {
	operation := host.runtime.binding_dom_string(host.argument(args, 0))!
	host.record(host.argument(args, 1), .subtle)!
	derive_key := operation == 'deriveKey'
	count := if derive_key { 5 } else { 2 }
	if args.len < count + 2 { return error('TypeError: ${operation}() needs ${count} arguments') }
	algorithm := args[2]
	is_object := C.JSValueIsObject(host.runtime.context, algorithm)
	mut converted := unsafe { algorithm }
	if !is_object { converted = host.runtime.binding_string(host.algorithm_string(algorithm)!) }
	host.runtime.retain_javascript_value(converted)!
	defer { host.runtime.release_javascript_value(converted) }
	record := host.record(args[3], .key)!
	key := unsafe { &webcrypto.CryptoKey(record.native) }
	if !derive_key {
		length := host.argument(args, 4)
		mut converted_length := ?u32(none)
		if !C.JSValueIsNull(host.runtime.context, length) && !C.JSValueIsUndefined(host.runtime.context, length) {
			converted_length = u32(webidl.convert_to_int(webidl.number_value(host.algorithm_number(length)!), 32, false, .no, .no)!)
		}
		normalized := host.normalize_derivation(converted, is_object)!
		return host.service.subtle().derive_bits(normalized, key, converted_length)
	}
	destination := args[4]
	destination_object := C.JSValueIsObject(host.runtime.context, destination)
	mut converted_destination := unsafe { destination }
	if !destination_object {
		converted_destination = host.runtime.binding_string(host.algorithm_string(destination)!)
	}
	host.runtime.retain_javascript_value(converted_destination)!
	defer { host.runtime.release_javascript_value(converted_destination) }
	extractable := C.JSValueToBoolean(host.runtime.context, args[5])
	usages := host.convert_crypto_usages(args[6])!
	normalized := host.normalize_derivation(converted, is_object)!
	import_params := host.normalize_import_for_operation(converted_destination, destination_object, 'importKey')!
	length_params := host.normalize_import_for_operation(converted_destination, destination_object, 'get key length')!
	return host.service.subtle().derive_key_with_parameter_snapshots(normalized, key, import_params, length_params, extractable, usages)
}
