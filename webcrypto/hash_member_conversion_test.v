// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import webidl
import x.json2

// Ladybird ad9a5581d4217917a3e8330838f1d62fdc116d53.
fn test_hash_members_convert_primitives_before_algorithm_normalization() {
	for hash in [json2.Any(1), json2.Any(true), json2.Any(json2.Null{})] {
		if _ := HmacKeyGenParams.from_value(json2.Any({'hash': hash})) {
			assert false
		} else {
			assert err.msg().starts_with('NotSupportedError:')
		}
	}
	if _ := HmacKeyGenParams.from_value(json2.Any(map[string]json2.Any{})) {
		assert false
	} else {
		assert err.msg() == 'TypeError: hash is required'
	}
	assert HmacKeyGenParams.from_value(json2.Any({'hash': json2.Any('SHA-256')}))!.hash == 'SHA-256'
}

fn test_binding_hash_dictionary_conversion_handles_missing_undefined_and_primitives() {
	for operation in ['generateKey', 'importKey', 'deriveBits', 'sign'] {
		name := match operation {
			'generateKey', 'importKey' { 'HMAC' }
			'deriveBits' { 'HKDF' }
			else { 'ECDSA' }
		}
		for hash in [webidl.undefined_value(), webidl.number_value(1), webidl.null_value(), webidl.boolean_value(true), webidl.bigint_value(1)] {
			value := webidl.object_value({'name': webidl.string_value(name), 'hash': hash})
			if _ := normalize_binding_algorithm(value, operation) {
				assert false
			} else {
				assert err.msg().starts_with(if hash.kind == .undefined { 'TypeError:' } else { 'NotSupportedError:' })
			}
		}
		if _ := normalize_binding_algorithm(webidl.object_value({'name': webidl.string_value(name)}), operation) {
			assert false
		} else {
			assert err.msg() == 'TypeError: hash is required'
		}
	}
}
