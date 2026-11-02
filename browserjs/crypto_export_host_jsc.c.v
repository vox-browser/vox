// Copyright (c) 2021-2022, Linus Groh <linusg@serenityos.org>
// Copyright (c) 2023-2024, stelar7 <dudedbz@gmail.com>
// Copyright (c) 2024, Jelle Raaijmakers <jelle@ladybird.org>
// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// SubtleCrypto.cpp exportKey and the pinned KeyFormat generated conversion.
module browserjs

import webcrypto
import webidl


fn (mut host CryptoHost) install_export_key() ! {
	mut runtime := unsafe { &Runtime(host.runtime) }
	handle := voidptr(&host)
	export := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &CryptoHost(handle) }
		native := host.export_key_operation(args) or { return host.rejected_crypto_promise(err) }
		return host.crypto_promise(native)
	})!
	installer := runtime.evaluate_host_value(r'(function(prototype,operate){Object.defineProperty(prototype,"exportKey",{value:function exportKey(format,key){return arguments.length<2?operate(this):operate(this,format,key)},writable:true,enumerable:true,configurable:true})})')!
	defer { runtime.release_javascript_value(installer) }
	prototype := host.prototypes[.subtle] or { return error('SubtleCrypto prototype unavailable') }
	runtime.call_javascript_function(installer, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		prototype,
		export,
	])!
}

fn (host &CryptoHost) convert_key_format(value voidptr) !webcrypto.KeyFormat {
	name := host.algorithm_string(value)!
	for format in [webcrypto.KeyFormat.raw_public, .raw_private, .raw_seed, .raw_secret, .raw,
		.spki, .pkcs8, .jwk] {
		if name == webcrypto.key_format_to_string(format) { return format }
	}
	return error("TypeError: Invalid value '${name}' for enumeration type 'KeyFormat'")
}

fn (mut host CryptoHost) export_key_operation(args []voidptr) !&webidl.Promise {
	host.record(host.argument(args, 0), .subtle)!
	if args.len < 3 { return error('TypeError: exportKey() needs 2 arguments') }
	format := host.convert_key_format(args[1])!
	record := host.record(args[2], .key)!
	key := unsafe { &webcrypto.CryptoKey(record.native) }
	// Normalization, extractability and the concrete export body run inside the
	// source service's owning deferred task, after both IDL conversions.
	return host.service.subtle().export_key(format, key)
}
