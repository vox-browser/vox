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
