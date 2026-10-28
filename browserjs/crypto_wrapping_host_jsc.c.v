// Copyright (c) 2021-2022, Linus Groh <linusg@serenityos.org>
// Copyright (c) 2023-2024, stelar7 <dudedbz@gmail.com>
// Copyright (c) 2024, Jelle Raaijmakers <jelle@ladybird.org>
// SPDX-License-Identifier: BSD-2-Clause
// Source wrapKey/unwrapKey binding conversion and normalization fallback.
module browserjs

import webcrypto
import webidl


fn (mut host CryptoHost) install_wrapping_operations() ! {
	mut runtime := unsafe { &Runtime(host.runtime) }
	handle := voidptr(&host)
	operate := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &CryptoHost(handle) }
		native := host.wrapping_operation(args) or { return host.rejected_crypto_promise(err) }
		return host.crypto_promise(native)
	})!
	installer := runtime.evaluate_host_value(r'(function(prototype,operate){const define=Object.defineProperty;define(prototype,"wrapKey",{value:function wrapKey(format,key,wrappingKey,wrapAlgorithm){return arguments.length<4?operate("wrapKey",this):operate("wrapKey",this,format,key,wrappingKey,wrapAlgorithm)},writable:true,enumerable:true,configurable:true});define(prototype,"unwrapKey",{value:function unwrapKey(format,wrappedKey,unwrappingKey,unwrapAlgorithm,unwrappedKeyAlgorithm,extractable,keyUsages){return arguments.length<7?operate("unwrapKey",this):operate("unwrapKey",this,format,wrappedKey,unwrappingKey,unwrapAlgorithm,unwrappedKeyAlgorithm,extractable,keyUsages)},writable:true,enumerable:true,configurable:true})})')!
	defer { runtime.release_javascript_value(installer) }
	prototype := host.prototypes[.subtle] or { return error('SubtleCrypto prototype unavailable') }
	runtime.call_javascript_function(installer, C.JSValueMakeUndefined(runtime.context), [
		prototype,
		operate,
	])!
}

fn (host &CryptoHost) normalize_wrapping(value voidptr, is_object bool, unwrap bool) !webidl.Value {
	first := if unwrap { 'unwrapKey' } else { 'wrapKey' }
	fallback := if unwrap { 'decrypt' } else { 'encrypt' }
	// Source catches every first-pass normalization exception and re-reads the
	// same actual algorithm for the encrypt/decrypt fallback.
	return host.normalize_cipher(value, is_object, first) or {
		host.normalize_cipher(value, is_object, fallback)!
	}
}

fn (mut host CryptoHost) wrapping_operation(args []voidptr) !&webidl.Promise {
	operation := host.runtime.binding_dom_string(host.argument(args, 0))!
	host.record(host.argument(args, 1), .subtle)!
	unwrap := operation == 'unwrapKey'
	count := if unwrap { 7 } else { 4 }
	if args.len < count + 2 { return error('TypeError: ${operation}() needs ${count} arguments') }
	format := host.convert_key_format(args[2])!
	mut target := &webcrypto.CryptoKey(unsafe { nil })
	if unwrap {
		host.validate_crypto_buffer(args[3], true)!
	} else {
		record := host.record(args[3], .key)!
		target = unsafe { &webcrypto.CryptoKey(record.native) }
	}
	record := host.record(args[4], .key)!
	key := unsafe { &webcrypto.CryptoKey(record.native) }
	algorithm := args[5]
	is_object := C.JSValueIsObject(host.runtime.context, algorithm)
	mut converted := unsafe { algorithm }
	if !is_object { converted = host.runtime.binding_string(host.algorithm_string(algorithm)!) }
	host.runtime.retain_javascript_value(converted)!
	defer { host.runtime.release_javascript_value(converted) }
	if !unwrap {
		normalized := host.normalize_wrapping(converted, is_object, false)!
		return host.service.subtle().wrap_key(format, target, key, normalized)
	}
	destination := args[6]
	destination_object := C.JSValueIsObject(host.runtime.context, destination)
	mut converted_destination := unsafe { destination }
	if !destination_object {
		converted_destination = host.runtime.binding_string(host.algorithm_string(destination)!)
	}
	host.runtime.retain_javascript_value(converted_destination)!
	defer { host.runtime.release_javascript_value(converted_destination) }
	extractable := C.JSValueToBoolean(host.runtime.context, args[7])
	usages := host.convert_crypto_usages(args[8])!
	normalized := host.normalize_wrapping(converted, is_object, true)!
	import_params := host.normalize_import(converted_destination, destination_object)!
	wrapped := host.copy_crypto_buffer(args[3])!
	return host.service.subtle().unwrap_key(format, wrapped, key, normalized, import_params, extractable, usages)
}
