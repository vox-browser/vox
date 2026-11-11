// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom

fn test_native_hash_member_conversion_rejects_missing_and_normalizes_primitives() {
	$if !darwin && !linux { return }
	url := dom.URL{value: 'https://crypto-hash.example/'}
	document := &dom.Document{ url: url, origin_: url.origin() }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := CryptoHost.create(document)!
	host.install(mut runtime)!
	for source in ['undefined', '1', 'null', 'true', '1n'] {
		value := runtime.evaluate_host_value(source)!
		if _ := host.crypto_hash_identifier(value) {
			assert false
		} else {
			assert err.msg().starts_with(if source == 'undefined' { 'TypeError:' } else { 'NotSupportedError:' })
		}
	}
	for source in ['"SHA-256"', '({name:"SHA-256"})'] {
		value := host.crypto_hash_identifier(runtime.evaluate_host_value(source)!)!
		assert value.object_value['name'].string_value == 'SHA-256'
	}
}
