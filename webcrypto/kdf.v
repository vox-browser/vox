// SPDX-License-Identifier: BSD-2-Clause
// CryptoAlgorithms.cpp HKDF/PBKDF2 algorithm operation bodies.
module webcrypto

fn hkdf_derive_bits(params HkdfParams, key &CryptoKey, length ?u32) ![]u8 {
	bits := length or { return error('OperationError: Length must be specified and divisible by 8') }
	if bits % 8 != 0 { return error('OperationError: Length must be specified and divisible by 8') }
	// HKDF-Expand has a hard limit of 255 hash output blocks (RFC 5869).
	// Validate the hash and requested size before returning an empty result or
	// passing an oversized allocation to the native derivation function.
	hash_length_bits := match params.hash {
		'SHA-1' { u32(160) }
		'SHA-256' { u32(256) }
		'SHA-384' { u32(384) }
		'SHA-512' { u32(512) }
		else { return error("NotSupportedError: Invalid hash function '${params.hash}'") }
	}
	if bits > u32(255) * hash_length_bits {
		return error('OperationError: Length is too large for the hash function')
	}
	if bits == 0 { return []u8{} }
	return native_kdf_derive(false, params.hash, key.handle_, params.salt, params.info, 0, int(bits / 8))
}

fn pbkdf2_derive_bits(params Pbkdf2Params, key &CryptoKey, length ?u32) ![]u8 {
	bits := length or { return error('OperationError: Length must be greater than 0 and divisible by 8') }
	if bits % 8 != 0 {
		return error('OperationError: Length must be greater than 0 and divisible by 8')
	}
	if params.iterations == 0 { return error('OperationError: Iterations must be greater than 0') }
	if params.hash !in ['SHA-1', 'SHA-256', 'SHA-384', 'SHA-512'] {
		return error("NotSupportedError: Invalid hash function '${params.hash}'")
	}
	return native_kdf_derive(true, params.hash, key.handle_, params.salt, [], params.iterations, int(bits / 8))
}

fn import_kdf_key(name string, format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey {
	if format !in [.raw, .raw_secret] {
		return error('NotSupportedError: Only raw format is supported')
	}
	for usage in usages {
		if usage !in [KeyUsage.derive_key, .derive_bits] {
			return error("SyntaxError: Invalid key usage '${key_usage_string(usage)}'")
		}
	}
	if extractable { return error('SyntaxError: extractable must be false') }
	return CryptoKey.create(.secret, false, KeyAlgorithm{ name: name }, [], material)
}
