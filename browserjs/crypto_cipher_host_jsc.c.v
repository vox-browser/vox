// Copyright (c) 2021-2022, Linus Groh <linusg@serenityos.org>
// Copyright (c) 2023-2024, stelar7 <dudedbz@gmail.com>
// Copyright (c) 2024, Jelle Raaijmakers <jelle@ladybird.org>
// Copyright (c) 2024, Andrew Kaster <akaster@serenityos.org>
// Copyright (c) 2024, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2024-2025, Altomani Gianluca <altomanigianluca@gmail.com>
// SPDX-License-Identifier: BSD-2-Clause
// Source encrypt/decrypt bindings and CryptoAlgorithms.cpp parameter bodies.
module browserjs

import webcrypto
import webidl


fn (mut host CryptoHost) install_cipher_operations() ! {
	mut runtime := unsafe { &Runtime(host.runtime) }
	handle := voidptr(&host)
	operate := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &CryptoHost(handle) }
		native := host.cipher_operation(args) or { return host.rejected_crypto_promise(err) }
		return host.crypto_promise(native)
	})!
	installer := runtime.evaluate_host_value(r'(function(prototype,operate){const define=Object.defineProperty;define(prototype,"encrypt",{value:function encrypt(algorithm,key,data){return arguments.length<3?operate("encrypt",this):operate("encrypt",this,algorithm,key,data)},writable:true,enumerable:true,configurable:true});define(prototype,"decrypt",{value:function decrypt(algorithm,key,data){return arguments.length<3?operate("decrypt",this):operate("decrypt",this,algorithm,key,data)},writable:true,enumerable:true,configurable:true})})')!
	defer { runtime.release_javascript_value(installer) }
	prototype := host.prototypes[.subtle] or { return error('SubtleCrypto prototype unavailable') }
	runtime.call_javascript_function(installer, C.JSValueMakeUndefined(runtime.context), [
		prototype,
		operate,
	])!
}

fn (host &CryptoHost) crypto_parameter_buffer(dictionary voidptr, field string) !webidl.Value {
	value := host.runtime.binding_property(dictionary, field)!
	// Concrete parameter bodies accept actual buffer brands without the
	// generated top-level shared/resizable argument restrictions.
	host.validate_crypto_buffer(value, false)!
	return webidl.buffer_source_value(host.copy_crypto_buffer(value)!)
}

fn (host &CryptoHost) normalize_cipher(value voidptr, is_object bool, operation string) !webidl.Value {
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
	if name == 'RSA-OAEP' {
		label := runtime.binding_property(dictionary, 'label')!
		if !C.JSValueIsNull(runtime.context, label) && !C.JSValueIsUndefined(runtime.context, label) {
			host.validate_crypto_buffer(label, false)!
			normalized['label'] = webidl.buffer_source_value(host.copy_crypto_buffer(label)!)
		}
	} else if name == 'AES-CTR' {
		normalized['counter'] = host.crypto_parameter_buffer(dictionary, 'counter')!
		normalized['length'] = host.generation_uint(dictionary, 'length', 8)!
	} else if name in ['AES-CBC', 'AES-GCM', 'AES-OCB', 'ChaCha20-Poly1305'] {
		normalized['iv'] = host.crypto_parameter_buffer(dictionary, 'iv')!
		if name != 'AES-CBC' {
			if host.algorithm_has(dictionary, 'additionalData')! {
				normalized['additionalData'] = host.crypto_parameter_buffer(dictionary, 'additionalData')!
			}
			if host.algorithm_has(dictionary, 'tagLength')! {
				normalized['tagLength'] = host.generation_uint(dictionary, 'tagLength', 8)!
			}
		}
	}
	return webidl.object_value(normalized)
}

fn (mut host CryptoHost) cipher_operation(args []voidptr) !&webidl.Promise {
	operation := host.runtime.binding_dom_string(host.argument(args, 0))!
	host.record(host.argument(args, 1), .subtle)!
	if args.len < 5 { return error('TypeError: ${operation}() needs 3 arguments') }
	algorithm := args[2]
	is_object := C.JSValueIsObject(host.runtime.context, algorithm)
	mut converted := unsafe { algorithm }
	if !is_object { converted = host.runtime.binding_string(host.algorithm_string(algorithm)!) }
	host.runtime.retain_javascript_value(converted)!
	defer { host.runtime.release_javascript_value(converted) }
	record := host.record(args[3], .key)!
	key := unsafe { &webcrypto.CryptoKey(record.native) }
	host.validate_crypto_buffer(args[4], true)!
	normalized := host.normalize_cipher(converted, is_object, operation)!
	data := host.copy_crypto_buffer(args[4])!
	if operation == 'decrypt' { return host.service.subtle().decrypt(normalized, key, data) }
	return host.service.subtle().encrypt(normalized, key, data)
}
