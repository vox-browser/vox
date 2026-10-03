// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Source Serializable identity comes from the actual CryptoKey wrapper owner.
module browserjs

import webcrypto

fn (runtime &Runtime) native_clone_crypto_key(value voidptr) ?&webcrypto.CryptoKey {
	host := crypto_bindings_[voidptr(runtime)] or { return none }
	if host.closed { return none }
	record := host.by_wrapper[value] or { return none }
	if record.kind != .key || voidptr(record.host) != voidptr(host) { return none }
	return unsafe { &webcrypto.CryptoKey(record.native) }
}
