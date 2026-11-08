// SPDX-License-Identifier: BSD-2-Clause
// CryptoAlgorithms.cpp MLKEM + LibCrypto/PK/MLKEM.cpp ASN.1 branches.
module webcrypto

fn mlkem_oid(name string) ![]u32 {
	last := match name {
		'ML-KEM-512' { 1 }
		'ML-KEM-768' { 2 }
		'ML-KEM-1024' { 3 }
		else { return error('NotSupportedError: Invalid algorithm') }
	}
	return [u32(2), 16, 840, 1, 101, 3, 4, 4, u32(last)]
}

fn mlkem_oid_bytes(name string) ![]u8 {
	oid := mlkem_oid(name)!
	return [u8(0x60), 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x04, u8(oid.last())]
}

fn mlkem_name_from_oid(oid []u32) !string {
	for name in ['ML-KEM-512', 'ML-KEM-768', 'ML-KEM-1024'] {
		if oid == mlkem_oid(name)! { return name }
	}
	return error('DataError: Invalid algorithm')
}

fn validate_mlkem_usages(usages []KeyUsage, private_key bool) ! {
	allowed := if private_key {
		[KeyUsage.decapsulate_key, .decapsulate_bits]
	} else {
		[KeyUsage.encapsulate_key, .encapsulate_bits]
	}
	for usage in usages {
		if usage !in allowed {
			return error("SyntaxError: Invalid key usage '${key_usage_string(usage)}'")
		}
	}
}

fn mlkem_private_key(name string, handle MlkemPrivateKeyHandle, extractable bool, usages []KeyUsage) &CryptoKey {
	return CryptoKey.create_with_internal_handle(.private_key, extractable, KeyAlgorithm{ name: name }, usages, handle)
}

fn mlkem_public_key(name string, bytes []u8, extractable bool, usages []KeyUsage) &CryptoKey {
	return CryptoKey.create_with_internal_handle(.public_key, extractable, KeyAlgorithm{ name: name }, usages, MlkemPublicKeyHandle{ public_key: bytes })
}

fn generate_mlkem_key(params AlgorithmParams, extractable bool, usages []KeyUsage) !GeneratedKey {
	for usage in usages {
		if usage !in [KeyUsage.encapsulate_key, .encapsulate_bits, .decapsulate_key, .decapsulate_bits] {
			return error('SyntaxError: Invalid key usage')
		}
	}
	handle := native_mlkem_generate(params.name, [])!
	return GeneratedKey{
		pair: CryptoKeyPair{
			public_key:  mlkem_public_key(params.name, handle.public_key, true, normalize_key_usages_for_operation(usages.filter(it in [
				KeyUsage.encapsulate_key,
				.encapsulate_bits,
			])))
			private_key: mlkem_private_key(params.name, handle, extractable, normalize_key_usages_for_operation(usages.filter(it in [
				KeyUsage.decapsulate_key,
				.decapsulate_bits,
			])))
		}
	}
}

fn (mut reader OkpDerReader) enter_ml_octet_string() ![]u8 {
	if reader.position >= reader.bytes.len || reader.bytes[reader.position] & 0x1f != 4 {
		return error('DataError: Expected OctetString')
	}
	if reader.bytes[reader.position] & 0x20 == 0 {
		return error('DataError: ASN1::Decoder: Entering a non-constructed type')
	}
	return reader.read(false)
}

fn read_mlkem_seed(mut reader OkpDerReader) ![]u8 {
	seed := reader.read(false)!
	if seed.len != 64 { return error('DataError: Invalid seed length') }
	return seed
}

fn read_mlkem_expanded(name string, mut reader OkpDerReader) ![]u8 {
	mut inner := OkpDerReader{ bytes: reader.enter_ml_octet_string()! }
	bytes := inner.read(false)!
	_, expected_size, _ := mlkem_sizes(name)!
	if bytes.len != expected_size { return error('DataError: Invalid expandedKey size') }
	return bytes
}

fn parse_mlkem_private(name string, bytes []u8) !MlkemPrivateKeyHandle {
	if bytes.len == 0 { return error('DataError: Input key is empty') }
	mut reader := OkpDerReader{ bytes: bytes }
	kind := bytes[0] & 0x1f
	if kind == 0 {
		return native_mlkem_generate(name, read_mlkem_seed(mut reader)!) or { return error('DataError: ${err.msg()}') }
	}
	if kind == 4 {
		return MlkemPrivateKeyHandle{ private_key: read_mlkem_expanded(name, mut reader)! }
	}
	if kind == 16 {
		mut both := OkpDerReader{ bytes: reader.read(true)! }
		mut seed_scope := OkpDerReader{ bytes: both.enter_ml_octet_string()! }
		handle := native_mlkem_generate(name, read_mlkem_seed(mut seed_scope)!) or { return error('DataError: ${err.msg()}') }
		// Source POP_SCOPE changes diagnostics, not the ASN.1 Decoder stack.
		// Preserve its ENTER_TYPED_SCOPE nesting for seed/expandedKey.
		mut expanded_scope := OkpDerReader{ bytes: seed_scope.enter_ml_octet_string()! }
		if read_mlkem_expanded(name, mut expanded_scope)! != handle.private_key {
			return error('DataError: Invalid expanded_key')
		}
		return handle
	}
	return error('DataError: Invalid key format')
}

fn import_mlkem_key(params AlgorithmParams, format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey {
	name := params.name
	match format {
		.spki {
			validate_mlkem_usages(usages, false)!
			info := parse_no_parameter_key_info(material, false)!
			if info.oid != mlkem_oid(name)! { return error('DataError: Invalid algorithm') }
			return mlkem_public_key(name, info.material, extractable, usages)
		}
		.pkcs8 {
			validate_mlkem_usages(usages, true)!
			info := parse_no_parameter_key_info(material, true)!
			parsed_name := mlkem_name_from_oid(info.oid)!
			handle := parse_mlkem_private(parsed_name, info.material)!
			if info.oid != mlkem_oid(name)! { return error('DataError: Invalid algorithm') }
			return mlkem_private_key(name, handle, false, [])
		}
		.raw_public {
			validate_mlkem_usages(usages, false)!
			return mlkem_public_key(name, material, false, [])
		}
		.raw_seed {
			validate_mlkem_usages(usages, true)!
			if material.len != 64 { return error('DataError: Invalid key format') }
			return mlkem_private_key(name, native_mlkem_generate(name, material)!, false, [])
		}
		.jwk { return import_mlkem_jwk(name, decode_json_web_key_dictionary(material)!, extractable, usages) }
		else { return error('NotSupportedError: Invalid key format') }
	}
}

fn export_mlkem_key(format KeyFormat, key &CryptoKey) ![]u8 {
	if format == .jwk { return export_mlkem_jwk(key)!.to_json().bytes() }
	if format in [.spki, .raw_public] {
		if key.type_ != .public_key { return error('InvalidAccessError: Key is not a public key') }
		handle := key.internal_handle_ as MlkemPublicKeyHandle
		if format == .raw_public { return handle.public_key.clone() }
		return wrap_no_parameter_key_info(mlkem_oid_bytes(key.algorithm_name())!, handle.public_key, false)
	}
	if format in [.pkcs8, .raw_seed] {
		if key.type_ != .private_key {
			return error('InvalidAccessError: Key is not a private key')
		}
		handle := key.internal_handle_ as MlkemPrivateKeyHandle
		if format == .raw_seed { return handle.seed.clone() }
		return wrap_no_parameter_key_info(mlkem_oid_bytes(key.algorithm_name())!, okp_der_value(0x80, handle.seed), true)
	}
	return error('NotSupportedError: Invalid key format')
}

// Modern Algorithms §6.4.5: AKP private JWKs carry the 64-byte (d,z)
// seed and must include its matching encapsulation key.
fn import_mlkem_jwk(name string, jwk JsonWebKey, extractable bool, usages []KeyUsage) !&CryptoKey {
	validate_mlkem_usages(usages, jwk.priv != none)!
	if (jwk.kty or { '' }) != 'AKP' { return error('DataError: Invalid key type') }
	if (jwk.alg or { '' }) != name { return error('DataError: Invalid algorithm') }
	if usages.len > 0 {
		if use_ := jwk.use { if use_ != 'enc' { return error('DataError: Invalid usage type') } }
	}
	validate_jwk_key_ops(jwk, usages)!
	if ext := jwk.ext { if !ext && extractable { return error('DataError: Invalid ext field') } }
	public_bytes := base64url_decode(jwk.pub_ or { return error('DataError: Missing public key') })!
	public_size, _, _ := mlkem_sizes(name)!
	if public_bytes.len != public_size { return error('DataError: Invalid public key length') }
	if private_text := jwk.priv {
		seed := base64url_decode(private_text)!
		if seed.len != 64 { return error('DataError: Invalid seed length') }
		handle := native_mlkem_generate(name, seed) or { return error('DataError: ${err.msg()}') }
		if handle.public_key != public_bytes { return error('DataError: Public and private keys do not match') }
		return mlkem_private_key(name, handle, extractable, usages)
	}
	return mlkem_public_key(name, public_bytes, extractable, usages)
}

fn export_mlkem_jwk(key &CryptoKey) !JsonWebKey {
	mut public_bytes := []u8{}
	mut private_text := ?string(none)
	match key.internal_handle_ {
		MlkemPublicKeyHandle { public_bytes = key.internal_handle_.public_key }
		MlkemPrivateKeyHandle {
			if key.internal_handle_.seed.len != 64 { return error('OperationError: Private seed is unavailable') }
			public_bytes = key.internal_handle_.public_key
			private_text = base64url_encode(key.internal_handle_.seed)
		}
		else { return error('OperationError: Invalid ML-KEM key handle') }
	}
	return JsonWebKey{kty: 'AKP', alg: key.algorithm_name(), pub_: base64url_encode(public_bytes), priv: private_text, key_ops: key.usages.map(key_usage_string(it)), ext: key.extractable}
}

fn mlkem_encapsulate(params AlgorithmParams, key &CryptoKey) !EncapsulatedBits {
	if is_hybrid_kem(params.name) { return hybrid_kem_encapsulate(params.name,key) }
	if key.type_ != .public_key { return error('InvalidAccessError: Invalid key type') }
	handle := key.internal_handle_ as MlkemPublicKeyHandle
	return native_mlkem_encapsulate(params.name, handle.public_key)
}

fn mlkem_decapsulate(params AlgorithmParams, key &CryptoKey, ciphertext []u8) ![]u8 {
	if is_hybrid_kem(params.name) { return hybrid_kem_decapsulate(params.name,key,ciphertext) }
	if key.type_ != .private_key { return error('InvalidAccessError: Invalid key type') }
	return native_mlkem_decapsulate(params.name, key.internal_handle_ as MlkemPrivateKeyHandle, ciphertext)
}
