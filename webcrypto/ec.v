// SPDX-License-Identifier: BSD-2-Clause
// CryptoAlgorithms.cpp ECDSA/ECDH operation bodies.
module webcrypto

fn generate_ec_key(params EcKeyGenParams, extractable bool, usages []KeyUsage) !GeneratedKey {
	allowed := if params.name == 'ECDH' {
		[KeyUsage.derive_key, .derive_bits]
	} else {
		[KeyUsage.sign, .verify]
	}
	for usage in usages {
		if usage !in allowed {
			return error("SyntaxError: Invalid key usage '${key_usage_string(usage)}'")
		}
	}
	if ec_scalar_size(params.named_curve) == 0 {
		return error("NotSupportedError: Only 'P-256', 'P-384' and 'P-521' is supported")
	}
	handle := native_ec_generate(params.named_curve) or { return error('OperationError: Failed to create valid crypto instance') }
	point := handle.public_key or { return error('OperationError: Failed to create valid crypto instance') }
	algorithm := EcKeyAlgorithm{ name: params.name, named_curve: params.named_curve }
	return GeneratedKey{
		pair: CryptoKeyPair{
			public_key:  CryptoKey.create_with_internal_handle(.public_key, true, algorithm, if params.name == 'ECDH' {
				[]KeyUsage{}
			} else {
				normalize_key_usages_for_operation(usages.filter(it == .verify))
			}, point)
			private_key: CryptoKey.create_with_internal_handle(.private_key, extractable, algorithm, normalize_key_usages_for_operation(usages.filter(it in if params.name == 'ECDH' {
				allowed
			} else {
				[KeyUsage.sign]
			})), handle)
		}
	}
}

fn ecdsa_digest(hash string, message []u8) ![]u8 {
	if hash !in ['SHA-1', 'SHA-256', 'SHA-384', 'SHA-512'] {
		return error("NotSupportedError: Invalid hash function '${hash}'")
	}
	return digest_bytes(hash, message)
}

fn ecdsa_sign(params EcdsaParams, key &CryptoKey, message []u8) ![]u8 {
	if key.type_ != .private_key { return error('InvalidAccessError: Key is not a private key') }
	digest := ecdsa_digest(params.hash, message)!
	curve := (key.algorithm as EcKeyAlgorithm).named_curve
	if ec_scalar_size(curve) == 0 { return error('DataError: Invalid algorithm') }
	return native_ec_sign(curve, (key.internal_handle_ as EcPrivateKeyHandle).d, digest)
}

fn ecdsa_verify(params EcdsaParams, key &CryptoKey, signature []u8, message []u8) !bool {
	if key.type_ != .public_key { return error('InvalidAccessError: Key is not a public key') }
	digest := ecdsa_digest(params.hash, message)!
	curve := (key.algorithm as EcKeyAlgorithm).named_curve
	if ec_scalar_size(curve) == 0 { return error('NotSupportedError: Invalid algorithm') }
	// Source splits at floor(size / 2), preserving its ignored final odd byte.
	return native_ec_verify(curve, key.internal_handle_ as EcPublicKeyHandle, signature, digest)
}

fn validate_ecdh_public_key(params EcdhKeyDeriveParams, length ?u32) ! {
	public_key := params.public_key
	if public_key.type_ != .public_key {
		return error('InvalidAccessError: Public key is not a public key')
	}
	// Check the algorithm name before extracting EC-specific algorithm data.
	// A foreign public key must not be cast to an EcKeyAlgorithm.
	if public_key.algorithm_name() != params.name || public_key.algorithm !is EcKeyAlgorithm {
		return error('InvalidAccessError: Algorithm mismatch')
	}
	public_algorithm := public_key.algorithm as EcKeyAlgorithm
	max_bytes := ec_scalar_size(public_algorithm.named_curve)
	if max_bytes == 0 { return error('InvalidAccessError: Unsupported public key curve') }
	if bits := length {
		if u64(bits) > u64(max_bytes) * 8 {
			return error('OperationError: Length is too large')
		}
	}
}

fn ecdh_derive_bits(params EcdhKeyDeriveParams, key &CryptoKey, length ?u32) ![]u8 {
	validate_ecdh_public_key(params, length)!
	if key.type_ != .private_key { return error('InvalidAccessError: Key is not a private key') }
	if key.algorithm !is EcKeyAlgorithm {
		return error('InvalidAccessError: Algorithm mismatch')
	}
	public_key := params.public_key
	algorithm := key.algorithm as EcKeyAlgorithm
	public_algorithm := public_key.algorithm as EcKeyAlgorithm
	if algorithm.name != public_algorithm.name {
		return error('InvalidAccessError: Algorithm mismatch')
	}
	if algorithm.named_curve != public_algorithm.named_curve {
		return error('InvalidAccessError: Curve mismatch')
	}
	if ec_scalar_size(algorithm.named_curve) == 0 { return error('DataError: Invalid algorithm') }
	point := native_ec_coordinate(algorithm.named_curve, (key.internal_handle_ as EcPrivateKeyHandle).d, public_key.internal_handle_ as EcPublicKeyHandle)!
	secret := point.x
	if bits := length {
		if u64(secret.len) * 8 < bits { return error('OperationError: Secret is too short') }
		mut result := secret[..int((bits + 7) / 8)].clone()
		if bits % 8 != 0 { result[result.len - 1] &= u8(0xff << (8 - bits % 8)) }
		return result
	}
	return secret
}
