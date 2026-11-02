// Copyright (c) 2021-2022, Linus Groh <linusg@serenityos.org>
// Copyright (c) 2023-2024, stelar7 <dudedbz@gmail.com>
// Copyright (c) 2024, Jelle Raaijmakers <jelle@ladybird.org>
// Copyright (c) 2024, Andrew Kaster <akaster@serenityos.org>
// Copyright (c) 2024, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2024-2025, Altomani Gianluca <altomanigianluca@gmail.com>
// SPDX-License-Identifier: BSD-2-Clause
// Source sign/verify and CryptoAlgorithms.cpp signature parameter conversion.
module browserjs

import webcrypto
import webidl


fn (mut host CryptoHost) install_signature_operations() ! {
	mut runtime := unsafe { &Runtime(host.runtime) }
	handle := voidptr(&host)
	operate := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &CryptoHost(handle) }
		native := host.signature_operation(args) or { return host.rejected_crypto_promise(err) }
		return host.crypto_promise(native)
	})!
	installer := runtime.evaluate_host_value(r'(function(prototype,operate){const define=Object.defineProperty;define(prototype,"sign",{value:function sign(algorithm,key,data){return arguments.length<3?operate("sign",this):operate("sign",this,algorithm,key,data)},writable:true,enumerable:true,configurable:true});define(prototype,"verify",{value:function verify(algorithm,key,signature,data){return arguments.length<4?operate("verify",this):operate("verify",this,algorithm,key,signature,data)},writable:true,enumerable:true,configurable:true})})')!
	defer { runtime.release_javascript_value(installer) }
	prototype := host.prototypes[.subtle] or { return error('SubtleCrypto prototype unavailable') }
	runtime.call_javascript_function(installer, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		prototype,
		operate,
	])!
}

fn (host &CryptoHost) normalize_signature(value voidptr, is_object bool, operation string) !webidl.Value {
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
	if name == 'ECDSA' {
		normalized['hash'] = host.crypto_hash_identifier(runtime.binding_property(dictionary, 'hash')!)!
	} else if name == 'RSA-PSS' {
		normalized['saltLength'] = host.generation_uint(dictionary, 'saltLength', 32)!
	} else if name == 'Ed448' || name.starts_with('ML-DSA-') {
		if host.algorithm_has(dictionary, 'context')! {
			normalized['context'] = host.crypto_parameter_buffer(dictionary, 'context')!
		}
	} else if name in ['KMAC128', 'KMAC256'] {
		if !host.algorithm_has(dictionary, 'outputLength')! {
			return error('TypeError: Required property outputLength is missing or undefined')
		}
		length := runtime.binding_property(dictionary, 'outputLength')!
		normalized['outputLength'] = webidl.number_value(webidl.convert_to_int(webidl.number_value(host.algorithm_number(length)!), 32, false, .yes, .no)!)
		if host.algorithm_has(dictionary, 'customization')! {
			normalized['customization'] = host.crypto_parameter_buffer(dictionary, 'customization')!
		}
	}
	return webidl.object_value(normalized)
}

fn (mut host CryptoHost) signature_operation(args []voidptr) !&webidl.Promise {
	operation := host.runtime.binding_dom_string(host.argument(args, 0))!
	host.record(host.argument(args, 1), .subtle)!
	verify := operation == 'verify'
	count := if verify { 4 } else { 3 }
	if args.len < count + 2 { return error('TypeError: ${operation}() needs ${count} arguments') }
	algorithm := args[2]
	is_object := C.JSValueIsObject(host.runtime.context, algorithm)
	mut converted := unsafe { algorithm }
	if !is_object { converted = host.runtime.binding_string(host.algorithm_string(algorithm)!) }
	host.runtime.retain_javascript_value(converted)!
	defer { host.runtime.release_javascript_value(converted) }
	record := host.record(args[3], .key)!
	key := unsafe { &webcrypto.CryptoKey(record.native) }
	host.validate_crypto_buffer(args[4], true)!
	if verify { host.validate_crypto_buffer(args[5], true)! }
	normalized := host.normalize_signature(converted, is_object, operation)!
	// verify copies signature first, then message, after source normalization.
	first := host.copy_crypto_buffer(args[4])!
	if verify {
		return host.service.subtle().verify(normalized, key, first, host.copy_crypto_buffer(args[5])!)
	}
	return host.service.subtle().sign(normalized, key, first)
}
