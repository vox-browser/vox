// SPDX-License-Identifier: BSD-2-Clause
// CryptoAlgorithms.cpp MLDSA + LibCrypto/PK/MLDSA.cpp operation bodies.
module webcrypto

fn mldsa_oid(name string) ![]u32 {
	last := match name {
		'ML-DSA-44' { 17 }
		'ML-DSA-65' { 18 }
		'ML-DSA-87' { 19 }
		else { return error('NotSupportedError: Invalid algorithm') }
	}
	return [u32(2), 16, 840, 1, 101, 3, 4, 3, u32(last)]
}

fn mldsa_oid_bytes(name string) ![]u8 {
	oid := mldsa_oid(name)!
	return [u8(0x60), 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x03, u8(oid.last())]
}

fn mldsa_name_from_oid(oid []u32) !string {
	for name in ['ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87'] {
		if oid == mldsa_oid(name)! { return name }
	}
	return error('DataError: Invalid algorithm')
}

fn validate_mldsa_usages(usages []KeyUsage, private_key bool) ! {
	allowed := if private_key {
		[KeyUsage.sign]
	} else {
		[KeyUsage.verify]
	}
	for usage in usages {
		if usage !in allowed {
			return error("SyntaxError: Invalid key usage '${key_usage_string(usage)}'")
		}
	}
}

fn mldsa_private_key(name string, handle MldsaPrivateKeyHandle, extractable bool, usages []KeyUsage) &CryptoKey {
	return CryptoKey.create_with_internal_handle(.private_key, extractable, KeyAlgorithm{ name: name }, usages, handle)
}

fn mldsa_public_key(name string, bytes []u8, extractable bool, usages []KeyUsage) &CryptoKey {
	return CryptoKey.create_with_internal_handle(.public_key, extractable, KeyAlgorithm{ name: name }, usages, MldsaPublicKeyHandle{ public_key: bytes })
}

fn generate_mldsa_key(params AlgorithmParams, extractable bool, usages []KeyUsage) !GeneratedKey {
	for usage in usages {
		if usage !in [KeyUsage.sign, .verify] {
			return error("SyntaxError: Invalid key usage '${key_usage_string(usage)}'")
		}
	}
	handle := native_mldsa_generate(params.name, [])!
	return GeneratedKey{
		pair: CryptoKeyPair{
			public_key:  mldsa_public_key(params.name, handle.public_key, true, normalize_key_usages_for_operation(usages.filter(it == .verify)))
			private_key: mldsa_private_key(params.name, handle, extractable, normalize_key_usages_for_operation(usages.filter(it == .sign)))
		}
	}
}

fn read_mldsa_seed(mut reader OkpDerReader) ![]u8 {
	seed := reader.read(false)!
	if seed.len != 32 { return error('DataError: Invalid seed length') }
	return seed
}

fn read_mldsa_expanded(name string, mut reader OkpDerReader) ![]u8 {
	mut inner := OkpDerReader{ bytes: reader.enter_ml_octet_string()! }
	bytes := inner.read(false)!
	_, expected_size, _ := mldsa_sizes(name)!
	if bytes.len != expected_size { return error('DataError: Invalid expandedKey size') }
	return bytes
}

fn parse_mldsa_private(name string, bytes []u8) !MldsaPrivateKeyHandle {
	if bytes.len == 0 { return error('DataError: Input key is empty') }
	mut reader := OkpDerReader{ bytes: bytes }
	kind := bytes[0] & 0x1f
	if kind == 0 {
		return native_mldsa_generate(name, read_mldsa_seed(mut reader)!) or { return error('DataError: ${err.msg()}') }
	}
	if kind == 4 {
		return MldsaPrivateKeyHandle{ private_key: read_mldsa_expanded(name, mut reader)! }
	}
	if kind == 16 {
		mut both := OkpDerReader{ bytes: reader.read(true)! }
		mut seed_scope := OkpDerReader{ bytes: both.enter_ml_octet_string()! }
		handle := native_mldsa_generate(name, read_mldsa_seed(mut seed_scope)!) or { return error('DataError: ${err.msg()}') }
		// Source POP_SCOPE changes diagnostics, not the ASN.1 Decoder stack.
		// Preserve its ENTER_TYPED_SCOPE nesting for seed/expandedKey.
		mut expanded_scope := OkpDerReader{ bytes: seed_scope.enter_ml_octet_string()! }
		if read_mldsa_expanded(name, mut expanded_scope)! != handle.private_key {
			return error('DataError: Invalid expanded_key')
		}
		return handle
	}
	return error('DataError: Invalid key format')
}

fn import_mldsa_key(params AlgorithmParams, format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey {
	name := params.name
	match format {
		.spki {
			validate_mldsa_usages(usages, false)!
			info := parse_no_parameter_key_info(material, false)!
			if info.oid != mldsa_oid(name)! { return error('DataError: Invalid algorithm') }
			return mldsa_public_key(name, info.material, extractable, usages)
		}
		.pkcs8 {
			validate_mldsa_usages(usages, true)!
			info := parse_no_parameter_key_info(material, true)!
			parsed_name := mldsa_name_from_oid(info.oid)!
			handle := parse_mldsa_private(parsed_name, info.material)!
			if info.oid != mldsa_oid(name)! { return error('DataError: Invalid algorithm') }
			return mldsa_private_key(name, handle, extractable, usages)
		}
		.raw_public {
			validate_mldsa_usages(usages, false)!
			return mldsa_public_key(name, material, false, [])
		}
		.raw_seed {
			validate_mldsa_usages(usages, true)!
			if material.len != 32 { return error('DataError: Seed must be 256 bits long') }
			return mldsa_private_key(name, native_mldsa_generate(name, material)!, false, [])
		}
		.jwk { return import_mldsa_jwk(name, decode_json_web_key_dictionary(material)!, usages, extractable) }
		else { return error('NotSupportedError: Invalid key format') }
	}
}

fn export_mldsa_key(format KeyFormat, key &CryptoKey) ![]u8 {
	if format in [.spki, .raw_public] {
		if key.type_ != .public_key { return error('InvalidAccessError: Key is not a public key') }
		handle := key.internal_handle_ as MldsaPublicKeyHandle
		if format == .raw_public { return handle.public_key.clone() }
		return wrap_no_parameter_key_info(mldsa_oid_bytes(key.algorithm_name())!, handle.public_key, false)
	}
	if format in [.pkcs8, .raw_seed] {
		if key.type_ != .private_key {
			return error('InvalidAccessError: Key is not a private key')
		}
		handle := key.internal_handle_ as MldsaPrivateKeyHandle
		if format == .raw_seed { return handle.seed.clone() }
		return wrap_no_parameter_key_info(mldsa_oid_bytes(key.algorithm_name())!, okp_der_value(0x80, handle.seed), true)
	}
	if format == .jwk { return export_mldsa_jwk(key).to_json().bytes() }
	return error('NotSupportedError: Invalid key format')
}

fn mldsa_sign(params Ed448Params, key &CryptoKey, message []u8) ![]u8 {
	if key.type_ != .private_key { return error('InvalidAccessError: Key is not a private key') }
	return native_mldsa_sign(params.name, key.internal_handle_ as MldsaPrivateKeyHandle, message, params.context or { []u8{} })
}

fn mldsa_verify(params Ed448Params, key &CryptoKey, signature []u8, message []u8) !bool {
	if key.type_ != .public_key { return error('InvalidAccessError: Key is not a public key') }
	return native_mldsa_verify(params.name, key.internal_handle_ as MldsaPublicKeyHandle, signature, message, params.context or { []u8{} })
}

fn import_mldsa_jwk(name string, jwk JsonWebKey, usages []KeyUsage, extractable bool) !&CryptoKey {
	private_key := jwk.priv != none
	for usage in usages {
		if usage != (if private_key { KeyUsage.sign } else { KeyUsage.verify }) {
			return error('SyntaxError: Invalid usage')
		}
	}
	if (jwk.kty or { '' }) != 'AKP' { return error('DataError: Invalid key type') }
	if (jwk.alg or { '' }) != name { return error('DataError: Invalid algorithm') }
	// A signing JWK may declare use="sig"; reject other declared uses.
	if usages.len != 0 {
		if use := jwk.use {
			if use != 'sig' { return error('DataError: Invalid usage type') }
		}
	}
	validate_jwk_key_ops(jwk, usages)!
	if ext := jwk.ext {
		if !ext && extractable { return error('DataError: Invalid ext field') }
	}
	if priv := jwk.priv {
		handle := native_mldsa_generate(name, base64url_decode(priv)!)!
		public_value := jwk.pub_ or { return error('DataError: JsonWebKey does not contain public key') }
		bytes := base64url_decode(public_value) or { return error('DataError: JsonWebKey public key does not match') }
		if bytes != handle.public_key {
			return error('DataError: JsonWebKey public key does not match')
		}
		return mldsa_private_key(name, handle, false, [])
	}
	public_value := jwk.pub_ or { return error('DataError: JsonWebKey does not contain public key') }
	return mldsa_public_key(name, base64url_decode(public_value)!, false, [])
}

fn export_mldsa_jwk(key &CryptoKey) JsonWebKey {
	public_value := match key.internal_handle_ {
		MldsaPublicKeyHandle { key.internal_handle_.public_key }
		MldsaPrivateKeyHandle { key.internal_handle_.public_key }
		else { panic('Invalid ML-DSA handle') }
	}
	priv := if key.type_ == .private_key {
		?string(base64url_encode((key.internal_handle_ as MldsaPrivateKeyHandle).seed))
	} else {
		none
	}
	return JsonWebKey{ kty: 'AKP', alg: key.algorithm_name(), pub_: base64url_encode(public_value), priv: priv, key_ops: key.usages.map(key_usage_string(it)), ext: key.extractable }
}
