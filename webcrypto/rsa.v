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

fn generate_rsa_key(params RsaHashedKeyGenParams, extractable bool, usages []KeyUsage) !GeneratedKey {
	mut allowed := rsa_allowed_usages(params.name, false)
	allowed << rsa_allowed_usages(params.name, true)
	for usage in usages {
		if usage !in allowed {
			return error("SyntaxError: Invalid key usage '${key_usage_string(usage)}'")
		}
	}
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
