// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

fn test_source_common_generation_runs_operation_before_empty_usage_check() {
	subtle := SubtleCrypto.create()
	if _ := subtle.generate_key(HmacKeyGenParams{ name: 'HMAC', hash: 'SHA-256', length: u32(0) }, false, []) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Invalid length'
	}
	if _ := subtle.generate_key(HmacKeyGenParams{ name: 'HMAC', hash: 'SHA3-256' }, false, []) {
		assert false
	} else {
		assert err.msg() == "NotSupportedError: Invalid hash function 'SHA3-256'"
	}
	if _ := subtle.generate_key(HmacKeyGenParams{ name: 'HMAC', hash: 'unknown' }, false, []) {
		assert false
	} else {
		assert err.msg() == "NotSupportedError: Algorithm 'unknown' is not supported for operation 'digest'"
	}
	for name in ['ECDSA', 'ECDH'] {
		if _ := subtle.generate_key(EcKeyGenParams{ name: name, named_curve: 'unsupported' }, false, []) {
			assert false
		} else {
			assert err.msg() == "NotSupportedError: Only 'P-256', 'P-384' and 'P-521' is supported"
		}
	}
	if _ := subtle.generate_key(RsaHashedKeyGenParams{ name: 'RSA-PSS', hash: 'SHA-256', modulus_length: 0, public_exponent: [
		u8(1),
		0,
		1,
	] }, false, []) {
		assert false
	} else {
		assert err.msg().starts_with('OperationError:')
	}
}

fn test_source_common_generation_still_rejects_successful_empty_secret_and_private_keys() {
	subtle := SubtleCrypto.create()
	for name in ['Ed25519', 'Ed448', 'X25519', 'X448', 'ML-DSA-44', 'ML-KEM-512', 'ChaCha20-Poly1305'] {
		if _ := subtle.generate_key(AlgorithmParams{ name: name }, false, []) {
			assert false, name
		} else {
			assert err.msg() == 'SyntaxError: usages must not be empty', name
		}
	}
	if _ := subtle.generate_key(HmacKeyGenParams{ name: 'HMAC', hash: 'SHA-256', length: u32(128) }, true, []) {
		assert false
	} else {
		assert err.msg() == 'SyntaxError: usages must not be empty'
	}
	for name in ['ECDSA', 'ECDH'] {
		if _ := subtle.generate_key(EcKeyGenParams{ name: name, named_curve: 'P-256' }, true, []) {
			assert false
		} else {
			assert err.msg() == 'SyntaxError: usages must not be empty'
		}
	}
	// Source class methods permit empty usages; the public boundary owns this check.
	for name in ['X25519', 'X448'] {
		pair := generate_exchange_key(name, false, [])!.pair or { panic('pair') }
		assert pair.private_key.usages.len == 0 && pair.public_key.usages.len == 0
		assert pair.private_key.handle().len == if name == 'X25519' { 32 } else { 56 }
	}
	key := generate_chacha_key(false, [])!.key or { panic('key') }
	assert key.usages.len == 0 && key.handle().len == 32
}
