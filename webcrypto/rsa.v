// SPDX-License-Identifier: BSD-2-Clause
// CryptoAlgorithms.cpp RSAOAEP/RSAPSS/RSASSAPKCS1 generation bodies.
module webcrypto

fn rsa_allowed_usages(name string, private_key bool) []KeyUsage {
	if name == 'RSA-OAEP' {
		return if private_key {
			[KeyUsage.decrypt, .unwrap_key]
		} else {
			[KeyUsage.encrypt, .wrap_key]
		}
	}
	return if private_key { [KeyUsage.sign] } else { [KeyUsage.verify] }
}

// WebCrypto's RSA generation parameters are validated before passing them to
// OpenSSL. In particular the public exponent must be an odd integer >= 3 and
// strictly less than 2^modulusLength - 1 (the final value has no room for the
// generated RSA modulus). publicExponent is an unsigned big-endian byte array.
fn validate_rsa_generation_parameters(modulus_length u32, public_exponent []u8) ! {
	if modulus_length < 4 {
		return error('OperationError: Invalid RSA key generation parameters')
	}
	mut first := 0
	for first < public_exponent.len && public_exponent[first] == 0 {
		first++
	}
	if first == public_exponent.len {
		return error('OperationError: Invalid RSA key generation parameters')
	}
	exponent := public_exponent[first..]
	if exponent[exponent.len - 1] & 1 == 0
		|| (exponent.len == 1 && exponent[0] < 3) {
		return error('OperationError: Invalid RSA key generation parameters')
	}
	// Length of the exponent's shortest unsigned representation in bits.
	mut leading_bits := u32(0)
	mut value := exponent[0]
	for value > 0 {
		leading_bits++
		value >>= 1
	}
	bits := u64(exponent.len - 1) * 8 + u64(leading_bits)
	if bits > u64(modulus_length) {
		return error('OperationError: Invalid RSA key generation parameters')
	}
	// The only n-bit exponent equal to 2^n - 1 has all n bits set.
	if bits == u64(modulus_length) {
		mut all_ones := exponent[0] == u8((u16(1) << leading_bits) - 1)
		for byte in exponent[1..] {
			if byte != 0xff { all_ones = false; break }
		}
		if all_ones {
			return error('OperationError: Invalid RSA key generation parameters')
		}
	}
}

fn generate_rsa_key(params RsaHashedKeyGenParams, extractable bool, usages []KeyUsage) !GeneratedKey {
	mut allowed := rsa_allowed_usages(params.name, false)
	allowed << rsa_allowed_usages(params.name, true)
	for usage in usages {
		if usage !in allowed {
			return error("SyntaxError: Invalid key usage '${key_usage_string(usage)}'")
		}
	}
	validate_rsa_generation_parameters(params.modulus_length, params.public_exponent)!
	handle := native_rsa_generate(params.modulus_length, params.public_exponent) or {
		if params.name == 'RSA-OAEP' {
			return error('OperationError: Failed generating RSA key pair')
		}
		return error('OperationError: Failed to generate RSA key pair')
	}
	algorithm := RsaHashedKeyAlgorithm{ name: params.name, modulus_length: params.modulus_length, public_exponent: handle.public_exponent, hash: params.hash }
	return GeneratedKey{
		pair: CryptoKeyPair{
			public_key:  CryptoKey.create_with_internal_handle(.public_key, true, algorithm, normalize_key_usages_for_operation(usages.filter(it in rsa_allowed_usages(params.name, false))), RsaPublicKeyHandle{ modulus: handle.modulus, public_exponent: handle.public_exponent })
			private_key: CryptoKey.create_with_internal_handle(.private_key, extractable, algorithm, normalize_key_usages_for_operation(usages.filter(it in rsa_allowed_usages(params.name, true))), handle)
		}
	}
}

fn rsa_oaep_encrypt(params RsaOaepParams, key &CryptoKey, message []u8) ![]u8 {
	if key.type_ != .public_key { return error('InvalidAccessError: Key is not a public key') }
	return native_rsa_oaep(key, message, params.label, false)
}

fn rsa_oaep_decrypt(params RsaOaepParams, key &CryptoKey, ciphertext []u8) ![]u8 {
	if key.type_ != .private_key { return error('InvalidAccessError: Key is not a private key') }
	return native_rsa_oaep(key, ciphertext, params.label, true)
}

fn rsa_sign(key &CryptoKey, message []u8, pss bool, salt u32) ![]u8 {
	if key.type_ != .private_key { return error('InvalidAccessError: Key is not a private key') }
	return native_rsa_sign(key, message, pss, salt)
}

fn rsa_verify(key &CryptoKey, signature []u8, message []u8, pss bool, salt u32) !bool {
	if key.type_ != .public_key { return error('InvalidAccessError: Key is not a public key') }
	return native_rsa_verify(key, signature, message, pss, salt)
}
