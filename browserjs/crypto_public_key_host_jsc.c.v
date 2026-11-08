// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// SubtleCrypto.getPublicKey generated IDL conversions and native dispatch.
module browserjs

import webcrypto
import webidl

fn (mut host CryptoHost) install_get_public_key() ! {
	mut runtime := unsafe { &Runtime(host.runtime) }
	handle := voidptr(&host)
	derive := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &CryptoHost(handle) }
		native := host.get_public_key_operation(args) or { return host.rejected_crypto_promise(err) }
		return host.crypto_promise(native)
	})!
	installer := runtime.evaluate_host_value(r'(function(prototype,operate){Object.defineProperty(prototype,"getPublicKey",{value:function getPublicKey(key,keyUsages){return arguments.length<2?operate(this):operate(this,key,keyUsages)},writable:true,enumerable:true,configurable:true})})')!
	defer { runtime.release_javascript_value(installer) }
	runtime.call_javascript_function(installer, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		host.prototypes[.subtle] or { return error('SubtleCrypto prototype unavailable') },
		derive,
	])!
}

fn (mut host CryptoHost) get_public_key_operation(args []voidptr) !&webidl.Promise {
	host.record(host.argument(args, 0), .subtle)!
	if args.len < 3 { return error('TypeError: getPublicKey() needs 2 arguments') }
	record := host.record(args[1], .key)!
	key := unsafe { &webcrypto.CryptoKey(record.native) }
	usages := host.convert_crypto_usages(args[2])!
	return host.service.subtle().get_public_key(key, usages)
}
