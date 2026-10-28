// Copyright (c) 2021-2022, Linus Groh <linusg@serenityos.org>
// Copyright (c) 2023-2024, stelar7 <dudedbz@gmail.com>
// Copyright (c) 2024, Jelle Raaijmakers <jelle@ladybird.org>
// SPDX-License-Identifier: BSD-2-Clause
// Source SubtleCrypto modern KEM methods and generated IDL conversions.
module browserjs

import webcrypto
import webidl


fn (mut host CryptoHost) install_kem_operations() ! {
	mut runtime := unsafe { &Runtime(host.runtime) }
	handle := voidptr(&host)
	operate := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &CryptoHost(handle) }
		native := host.kem_operation(args) or { return host.rejected_crypto_promise(err) }
		return host.crypto_promise(native)
	})!
	installer := runtime.evaluate_host_value(r'(function(prototype,operate){const define=Object.defineProperty;define(prototype,"encapsulateBits",{value:function encapsulateBits(algorithm,key){return arguments.length<2?operate("encapsulateBits",this):operate("encapsulateBits",this,algorithm,key)},writable:true,enumerable:true,configurable:true});define(prototype,"encapsulateKey",{value:function encapsulateKey(algorithm,key,sharedKeyAlgorithm,extractable,keyUsages){return arguments.length<5?operate("encapsulateKey",this):operate("encapsulateKey",this,algorithm,key,sharedKeyAlgorithm,extractable,keyUsages)},writable:true,enumerable:true,configurable:true});define(prototype,"decapsulateBits",{value:function decapsulateBits(algorithm,key,ciphertext){return arguments.length<3?operate("decapsulateBits",this):operate("decapsulateBits",this,algorithm,key,ciphertext)},writable:true,enumerable:true,configurable:true});define(prototype,"decapsulateKey",{value:function decapsulateKey(algorithm,key,ciphertext,sharedKeyAlgorithm,extractable,keyUsages){return arguments.length<6?operate("decapsulateKey",this):operate("decapsulateKey",this,algorithm,key,ciphertext,sharedKeyAlgorithm,extractable,keyUsages)},writable:true,enumerable:true,configurable:true})})')!
	defer { runtime.release_javascript_value(installer) }
	prototype := host.prototypes[.subtle] or { return error('SubtleCrypto prototype unavailable') }
	runtime.call_javascript_function(installer, C.JSValueMakeUndefined(runtime.context), [
		prototype,
		operate,
	])!
}

fn (host &CryptoHost) normalize_kem(value voidptr, is_object bool, encapsulate bool) !webidl.Value {
	mut runtime := unsafe { &Runtime(host.runtime) }
	dictionary := host.algorithm_dictionary(value, is_object)!
	runtime.retain_javascript_value(dictionary)!
	defer { runtime.release_javascript_value(dictionary) }
	initial_name := runtime.binding_property(dictionary, 'name')!
	if C.JSValueIsUndefined(runtime.context, initial_name) {
		return error('TypeError: Not an object of type Algorithm')
	}
	operation := if encapsulate { 'encapsulate' } else { 'decapsulate' }
	name := webcrypto.normalize_an_algorithm(host.algorithm_string(initial_name)!, operation)!
	return webidl.object_value({
		'name': webidl.string_value(name)
	})
}

fn (mut host CryptoHost) kem_operation(args []voidptr) !&webidl.Promise {
	operation := host.runtime.binding_dom_string(host.argument(args, 0))!
	host.record(host.argument(args, 1), .subtle)!
	encapsulate := operation.starts_with('encapsulate')
	key_result := operation.ends_with('Key')
	count := if key_result {
		if encapsulate { 5 } else { 6 }
	} else {
		if encapsulate { 2 } else { 3 }
	}
	if args.len < count + 2 { return error('TypeError: ${operation}() needs ${count} arguments') }
	algorithm := args[2]
	is_object := C.JSValueIsObject(host.runtime.context, algorithm)
	mut converted := unsafe { algorithm }
	if !is_object { converted = host.runtime.binding_string(host.algorithm_string(algorithm)!) }
	host.runtime.retain_javascript_value(converted)!
	defer { host.runtime.release_javascript_value(converted) }
	record := host.record(args[3], .key)!
	key := unsafe { &webcrypto.CryptoKey(record.native) }
	if !encapsulate { host.validate_crypto_buffer(args[4], true)! }
	if !key_result {
		if encapsulate {
			return host.service.subtle().encapsulate_bits(host.normalize_kem(converted, is_object, true)!, key)
		}
		ciphertext := host.copy_crypto_buffer(args[4])!
		return host.service.subtle().decapsulate_bits(host.normalize_kem(converted, is_object, false)!, key, ciphertext)
	}
	destination_index := if encapsulate { 4 } else { 5 }
	destination := args[destination_index]
	destination_object := C.JSValueIsObject(host.runtime.context, destination)
	mut converted_destination := unsafe { destination }
	if !destination_object {
		converted_destination = host.runtime.binding_string(host.algorithm_string(destination)!)
	}
	host.runtime.retain_javascript_value(converted_destination)!
	defer { host.runtime.release_javascript_value(converted_destination) }
	extractable := C.JSValueToBoolean(host.runtime.context, args[destination_index + 1])
	usages := host.convert_crypto_usages(args[destination_index + 2])!
	mut ciphertext := webidl.BufferSource.array_buffer([]u8{})
	if !encapsulate { ciphertext = host.copy_crypto_buffer(args[4])! }
	normalized := host.normalize_kem(converted, is_object, encapsulate)!
	shared_algorithm := host.normalize_import(converted_destination, destination_object)!
	if encapsulate {
		return host.service.subtle().encapsulate_key(normalized, key, shared_algorithm, extractable, usages)
	}
	return host.service.subtle().decapsulate_key(normalized, key, ciphertext, shared_algorithm, extractable, usages)
}
