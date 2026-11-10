// SPDX-License-Identifier: BSD-2-Clause
// Translation of the X25519/X448 operation bodies in CryptoAlgorithms.cpp.
module webcrypto

fn validate_exchange_usages(usages []KeyUsage) ! {
	for usage in usages {
		if usage !in [KeyUsage.derive_key, .derive_bits] {
			return error("SyntaxError: Invalid key usage '${key_usage_string(usage)}'")
		}
	}
}

fn exchange_key(name string, private_key bool, material []u8, extractable bool, usages []KeyUsage) &CryptoKey {
	if private_key {
		return CryptoKey.create_with_internal_handle(.private_key, extractable, KeyAlgorithm{ name: name }, usages, OkpPrivateKeyHandle{ bytes: material })
	}
	return CryptoKey.create_with_internal_handle(.public_key, extractable, KeyAlgorithm{ name: name }, usages, OkpPublicKeyHandle{ bytes: material })
}

fn generate_exchange_key(name string, extractable bool, usages []KeyUsage) !GeneratedKey {
	validate_exchange_usages(usages)!
	private_bytes := native_edwards_private(name)!
	public_bytes := native_edwards_public(name, private_bytes)!
	return GeneratedKey{
		pair: CryptoKeyPair{
			public_key:  exchange_key(name, false, public_bytes, true, [])
			private_key: exchange_key(name, true, private_bytes, extractable, normalize_key_usages_for_operation(usages))
		}
	}
}

fn validate_exchange_public_key(name string, params EcdhKeyDeriveParams, length ?u32) ! {
	public_key := params.public_key
	if public_key.type_ != .public_key {
		return error('InvalidAccessError: Public key is not a public key')
	}
	if public_key.algorithm_name() != name {
		return error('InvalidAccessError: Algorithm mismatch')
	}
	if bits := length {
		if u64(bits) > u64(exchange_key_size(name)) * 8 {
			return error('OperationError: Length is too large')
		}
	}
}

fn derive_exchange_bits(name string, params EcdhKeyDeriveParams, key &CryptoKey, length ?u32) ![]u8 {
	// Only X25519 validates public parameters before the private key type.
	if name == 'X25519' {
		validate_exchange_public_key(name, params, length)!
	}
	if key.type_ != .private_key { return error('InvalidAccessError: Key is not a private key') }
	public_key := params.public_key
	if public_key.type_ != .public_key {
		return error('InvalidAccessError: Public key is not a public key')
	}
	if public_key.algorithm_name() != key.algorithm_name() {
		return error('InvalidAccessError: Algorithm mismatch')
	}
	secret := native_edwards_coordinate(name, key.handle_, public_key.handle_)!
	mut or_bytes := u8(0)
	for byte in secret { or_bytes |= byte }
	if or_bytes == 0 { return error('OperationError: Secret is the all-zero value') }
	if bits := length {
		if u64(secret.len) * 8 < u64(bits) { return error('OperationError: Secret is too short') }
		mut result := secret[..int((u64(bits) + 7) / 8)].clone()
		if bits % 8 != 0 { result[result.len - 1] &= u8(0xff << (8 - (bits % 8))) }
		return result
	}
	return secret.clone()
}

fn import_exchange_jwk(name string, jwk JsonWebKey, extractable bool, usages []KeyUsage) !&CryptoKey {
	private_key := jwk.d != none
	if private_key {
		validate_exchange_usages(usages)!
	} else if usages.len != 0 {
		message := if name == 'X25519' {
			'Usages must be empty if d is missing'
		} else {
			'Usages must be empty'
		}
		return error('SyntaxError: ${message}')
	}
	if (jwk.kty or { '' }) != 'OKP' { return error('DataError: Invalid key type') }
	if (jwk.crv or { '' }) != name { return error('DataError: Invalid curve') }
	if usages.len != 0 {
		if use := jwk.use {
			if use != 'enc' { return error('DataError: Invalid use') }
		}
	}
	validate_jwk_key_ops(jwk, usages)!
	if ext := jwk.ext {
		if !ext && extractable { return error('DataError: Invalid extractable') }
	}
	encoded_public := jwk.x or { return error('DataError: Missing x field') }
	public_bytes := base64url_decode(encoded_public)!
	if public_bytes.len != exchange_key_size(name) { return error('DataError: Invalid key length') }
	if encoded_private := jwk.d {
		private_bytes := base64url_decode(encoded_private)!
		if private_bytes.len != exchange_key_size(name) {
			return error('DataError: Invalid key length')
		}
		if native_edwards_public(name, private_bytes)! != public_bytes {
			return error('DataError: Invalid key pair')
		}
		return exchange_key(name, true, private_bytes, false, [])
	}
	return exchange_key(name, false, public_bytes, false, [])
}

fn import_exchange_key(name string, format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey {
	match format {
		.spki {
			if usages.len != 0 { return error('SyntaxError: Usages must be empty') }
			return exchange_key(name, false, parse_okp_der(name, material, false)!, false, [])
		}
		.pkcs8 {
			validate_exchange_usages(usages)!
			return exchange_key(name, true, parse_okp_der(name, material, true)!, false, [])
		}
		.jwk { return import_exchange_jwk(name, decode_json_web_key_dictionary(material)!, extractable, usages) }
		.raw, .raw_public {
			// X448's source has only the raw branch, unlike X25519's alias.
			if name == 'X448' && format == .raw_public {
				return error('NotSupportedError: Invalid key format')
			}
			if usages.len != 0 { return error('SyntaxError: Usages must be empty') }
			if material.len != exchange_key_size(name) {
				return error('DataError: Invalid key length')
			}
			return exchange_key(name, false, material, false, [])
		}
		else { return error('NotSupportedError: Invalid key format') }
	}
}

fn export_exchange_jwk(name string, key &CryptoKey) !JsonWebKey {
	public_bytes := if key.type_ == .public_key {
		key.handle_.clone()
	} else {
		native_edwards_public(name, key.handle_)!
	}
	return JsonWebKey{
		kty:     'OKP'
		crv:     name
		x:       base64url_encode(public_bytes)
		d:       if key.type_ == .private_key { base64url_encode(key.handle_) } else { none }
		key_ops: key.usages.map(key_usage_string(it))
		ext:     key.extractable
	}
}

fn export_exchange_key(name string, format KeyFormat, key &CryptoKey) ![]u8 {
	match format {
		.spki {
			if key.type_ != .public_key {
				return error('InvalidAccessError: Key is not a public key')
			}
			return export_okp_der(name, key.handle_, false)
		}
		.pkcs8 {
			if key.type_ != .private_key {
				return error('InvalidAccessError: Key is not a private key')
			}
			return export_okp_der(name, key.handle_, true)
		}
		.jwk { return export_exchange_jwk(name, key)!.to_json().bytes() }
		.raw, .raw_public {
			if name == 'X448' && format == .raw_public {
				return error('NotSupportedError: Invalid key format')
			}
			if key.type_ != .public_key {
				return error('InvalidAccessError: Key is not a public key')
			}
			return key.handle_.clone()
		}
		else { return error('NotSupportedError: Invalid key format') }
	}
}
