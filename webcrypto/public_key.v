// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// SubtleCrypto.cpp public_key_for_private_key and getPublicKey.
module webcrypto

pub fn public_key_usages(name string) ![]KeyUsage {
	normalize_an_algorithm(name, 'exportKey') or {
		return error("NotSupportedError: Algorithm '${name}' does not support deriving a public key")
	}
	return match name {
		'RSA-OAEP' { [KeyUsage.encrypt, .wrap_key] }
		'RSASSA-PKCS1-v1_5', 'RSA-PSS', 'ECDSA', 'Ed25519', 'Ed448',
		'ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87' { [KeyUsage.verify] }
		'ECDH', 'X25519', 'X448' { []KeyUsage{} }
		'ML-KEM-512', 'ML-KEM-768', 'ML-KEM-1024', 'MLKEM768-P256', 'MLKEM768-X25519', 'MLKEM1024-P384' { [KeyUsage.encapsulate_bits, .encapsulate_key] }
		else { return error("NotSupportedError: Algorithm '${name}' does not support deriving a public key") }
	}
}

fn public_key_for_private_key(key &CryptoKey) !CryptoKeyInternalHandle {
	return match key.internal_handle_ {
		ByteBufferKeyHandle {
			if !is_hybrid_kem(key.algorithm_name()) { return error('Unsupported private key') }
			ByteBufferKeyHandle{ bytes: hybrid_kem_public(key.algorithm_name(),key.internal_handle_.bytes)! }
		}
		RsaPrivateKeyHandle {
			RsaPublicKeyHandle{ modulus: key.internal_handle_.modulus, public_exponent: key.internal_handle_.public_exponent }
		}
		EcPrivateKeyHandle {
			if point := key.internal_handle_.public_key {
				point
			} else {
				if key.algorithm !is EcKeyAlgorithm { return error('Invalid EC algorithm') }
				algorithm := key.algorithm as EcKeyAlgorithm
				if ec_scalar_size(algorithm.named_curve) == 0 { return error('Unsupported named curve') }
				native_ec_public(algorithm.named_curve, key.internal_handle_.d)!
			}
		}
		MldsaPrivateKeyHandle { MldsaPublicKeyHandle{ public_key: key.internal_handle_.public_key } }
		MlkemPrivateKeyHandle { MlkemPublicKeyHandle{ public_key: key.internal_handle_.public_key } }
		OkpPrivateKeyHandle {
			name := key.algorithm_name()
			if name !in ['Ed25519', 'Ed448', 'X25519', 'X448'] { return error('Unsupported algorithm') }
			OkpPublicKeyHandle{ bytes: native_edwards_public(name, key.internal_handle_.bytes)! }
		}
		else { return error('Key does not contain a private-key handle') }
	}
}

pub fn (_ &SubtleCrypto) get_public_key(key &CryptoKey, usages []KeyUsage) !&CryptoKey {
	allowed := public_key_usages(key.algorithm_name())!
	if key.type_ != .private_key { return error('InvalidAccessError: Key is not a private key') }
	for usage in usages {
		if usage !in allowed { return error('SyntaxError: Invalid key usage for a public key') }
	}
	handle := public_key_for_private_key(key) or { return error('OperationError: Failed to derive the public key') }
	return CryptoKey.create_with_internal_handle(.public_key, true, key.algorithm, normalize_key_usages(usages), handle)
}
