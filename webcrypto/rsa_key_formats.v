// SPDX-License-Identifier: BSD-2-Clause
// CryptoAlgorithms.cpp RSA key format bodies, Certificate.cpp and PK/RSA.cpp.
module webcrypto

const rsa_oid = [u32(1), 2, 840, 113549, 1, 1, 1]
const rsa_oid_bytes = [u8(0x2a), 0x86, 0x48, 0x86, 0xf7, 0x0d, 1, 1, 1]

fn (mut reader OkpDerReader) read_rsa_integer() ![]u8 {
	bytes := reader.read(false)!
	if bytes.len == 0 {
		return error('DataError: ASN1::Decoder: Decoding arbitrary sized integer from an empty span')
	}
	if bytes.len > 1 && ((bytes[0] == 0xff && bytes[1] & 0x80 != 0) || (bytes[0] == 0 && bytes[1] & 0x80 == 0)) {
		return error('DataError: ASN1::Decoder: Arbitrary sized integer has an invalid format')
	}
	if bytes[0] & 0x80 != 0 {
		return error('DataError: ASN1::Decoder: Decoding a negative unsigned arbitrary sized integer')
	}
	return unsigned_big_integer_bytes(bytes)
}

fn parse_rsa_der(bytes []u8, private_key bool) !CryptoKeyInternalHandle {
	mut outer := OkpDerReader{ bytes: bytes }
	mut inner := OkpDerReader{ bytes: outer.read(true)! }
	if private_key && inner.read_rsa_integer()! != [u8(0)] {
		return error('DataError: Invalid version value')
	}
	n := inner.read_rsa_integer()!
	e := inner.read_rsa_integer()!
	if !private_key { return RsaPublicKeyHandle{ modulus: n, public_exponent: e } }
	return RsaPrivateKeyHandle{
		modulus:          n
		public_exponent:  e
		private_exponent: inner.read_rsa_integer()!
		prime1:           inner.read_rsa_integer()!
		prime2:           inner.read_rsa_integer()!
		exponent1:        inner.read_rsa_integer()!
		exponent2:        inner.read_rsa_integer()!
		coefficient:      inner.read_rsa_integer()!
	}
	// Source EXIT_SCOPE discards unread inner bytes and doesn't check inner DER eof.
}

fn parse_rsa_key_info(bytes []u8, private_key bool) !CryptoKeyInternalHandle {
	info := parse_no_parameter_key_info(bytes, private_key)!
	if info.oid != rsa_oid {
		return error('DataError: Algorithm object identifier is not the rsaEncryption object identifier')
	}
	// Certificate.cpp requires one RSA NULL parameter. READ_OBJECT overrides
	// its class/kind; the null decoder requires empty contents.
	mut outer := OkpDerReader{ bytes: bytes }
	mut body := OkpDerReader{ bytes: outer.read(true)! }
	if private_key { body.read_rsa_integer()! }
	mut algorithm := OkpDerReader{ bytes: body.read(true)! }
	algorithm.read(false)!
	if algorithm.read(false)!.len != 0 {
		return error('DataError: ASN1::Decoder: Decoding null from a non-empty span')
	}
	return parse_rsa_der(info.material, private_key)
}

fn rsa_jwk_algorithm(name string, hash string) !string {
	suffix := match hash {
		'SHA-1' { '1' }
		'SHA-256' { '256' }
		'SHA-384' { '384' }
		'SHA-512' { '512' }
		else { return error('DataError: Invalid algorithm') }
	}
	return match name {
		'RSA-OAEP' {
			if suffix == '1' { 'RSA-OAEP' } else { 'RSA-OAEP-${suffix}' }
		}
		'RSA-PSS' { 'PS${suffix}' }
		else { 'RS${suffix}' }
	}
}

fn parse_rsa_jwk(params RsaHashedImportParams, jwk JsonWebKey, extractable bool, usages []KeyUsage) !CryptoKeyInternalHandle {
	private_key := jwk.d != none
	for usage in usages {
		if usage !in rsa_allowed_usages(params.name, private_key) {
			return error("SyntaxError: Invalid key usage '${key_usage_string(usage)}'")
		}
	}
	if (jwk.kty or { '' }) != 'RSA' { return error('DataError: Invalid key type') }
	if usages.len != 0 {
		if use := jwk.use {
			if use != (if params.name == 'RSA-OAEP' { 'enc' } else { 'sig' }) {
				return error('DataError: Invalid use field')
			}
		}
	}
	validate_jwk_key_ops(jwk, usages)!
	if ext := jwk.ext {
		if !ext && extractable { return error('DataError: Invalid ext field') }
	}
	if alg := jwk.alg {
		mut found := false
		for hash in ['SHA-1', 'SHA-256', 'SHA-384', 'SHA-512'] {
			if alg == rsa_jwk_algorithm(params.name, hash)! {
				if hash != params.hash { return error('DataError: Invalid hash') }
				found = true
				break
			}
		}
		if !found { return error('DataError: Invalid algorithm') }
	}
	if private_key {
		mut meets_requirements := jwk.e != none && jwk.n != none && jwk.d != none
		if jwk.p != none || jwk.q != none || jwk.dp != none || jwk.dq != none || jwk.qi != none {
			// CRT parameters are optional only as a complete group.
			meets_requirements = meets_requirements && (jwk.p != none && jwk.q != none && jwk.dp != none && jwk.dq != none && jwk.qi != none)
		}
		if jwk.oth != none { meets_requirements = false }
		if !meets_requirements { return error('DataError: Invalid JWK private key') }
		data := parse_jwk_rsa_private_key(jwk)!
		return RsaPrivateKeyHandle{
			modulus:          data.modulus
			public_exponent:  data.public_exponent
			private_exponent: data.private_exponent
			prime1:           data.first_prime or { []u8{} }
			prime2:           data.second_prime or { []u8{} }
			exponent1:        data.first_exponent or { []u8{} }
			exponent2:        data.second_exponent or { []u8{} }
			coefficient:      data.coefficient or { []u8{} }
		}
	}
	if jwk.e == none || jwk.n == none { return error('DataError: Invalid JWK public key') }
	data := parse_jwk_rsa_public_key(jwk)!
	return RsaPublicKeyHandle{ modulus: data.modulus, public_exponent: data.public_exponent }
}

fn import_rsa_key(params RsaHashedImportParams, format KeyFormat, bytes []u8, extractable bool, usages []KeyUsage) !&CryptoKey {
	mut private_key := format == .pkcs8
	handle := if format == .jwk {
		jwk := decode_json_web_key_dictionary(bytes)!
		private_key = jwk.d != none
		parse_rsa_jwk(params, jwk, extractable, usages)!
	} else if format in [.spki, .pkcs8] {
		for usage in usages {
			if usage !in rsa_allowed_usages(params.name, private_key) {
				return error("SyntaxError: Invalid key usage '${key_usage_string(usage)}'")
			}
		}
		parse_rsa_key_info(bytes, private_key)!
	} else {
		return error('NotSupportedError: Unsupported key format')
	}
	validate_rsa_handle(handle, private_key)!
	n, e := match handle {
		RsaPublicKeyHandle { handle.modulus, handle.public_exponent }
		RsaPrivateKeyHandle { handle.modulus, handle.public_exponent }
		else { panic('Invalid RSA handle') }
	}
	algorithm := RsaHashedKeyAlgorithm{ name: params.name, hash: params.hash, modulus_length: u32(n.len * 8), public_exponent: e }
	// SubtleCrypto.importKey installs extractability/usages after class import.
	return CryptoKey.create_with_internal_handle(if private_key {
		KeyType.private_key
	} else {
		KeyType.public_key
	}, false, algorithm, [], handle)
}

fn rsa_der_integer(bytes []u8) []u8 {
	mut value := unsigned_big_integer_bytes(bytes)
	if value[0] & 0x80 != 0 { value.insert(0, u8(0)) }
	return okp_der_value(0x02, value)
}

fn export_rsa_der(handle CryptoKeyInternalHandle, private_key bool) ![]u8 {
	mut bytes := []u8{}
	match handle {
		RsaPublicKeyHandle {
			bytes << rsa_der_integer(handle.modulus)
			bytes << rsa_der_integer(handle.public_exponent)
		}
		RsaPrivateKeyHandle {
			if handle.prime1.all(it == 0) || handle.prime2.all(it == 0) {
				return error('OperationError: Cannot export private key without prime factors')
			}
			bytes << rsa_der_integer([u8(0)])
			for value in [handle.modulus, handle.public_exponent, handle.private_exponent,
				handle.prime1, handle.prime2, handle.exponent1, handle.exponent2, handle.coefficient] {
				bytes << rsa_der_integer(value)
			}
		}
		else { panic('Invalid RSA handle') }
	}
	mut identifier := okp_der_value(0x06, rsa_oid_bytes)
	identifier << okp_der_value(0x05, [])
	mut body := []u8{}
	if private_key { body << rsa_der_integer([u8(0)]) }
	body << okp_der_value(0x30, identifier)
	material := okp_der_value(0x30, bytes)
	if private_key {
		body << okp_der_value(0x04, material)
	} else {
		mut bitstring := [u8(0)]
		bitstring << material
		body << okp_der_value(0x03, bitstring)
	}
	return okp_der_value(0x30, body)
}

fn export_rsa_jwk(key &CryptoKey) !JsonWebKey {
	algorithm := key.algorithm as RsaHashedKeyAlgorithm
	mut jwk := JsonWebKey{ kty: 'RSA', alg: rsa_jwk_algorithm(algorithm.name, algorithm.hash)!, key_ops: key.usages.map(key_usage_string(it)), ext: key.extractable }
	match key.internal_handle_ {
		RsaPublicKeyHandle {
			jwk.n = base64_url_uint_encode(key.internal_handle_.modulus)
			jwk.e = base64_url_uint_encode(key.internal_handle_.public_exponent)
		}
		RsaPrivateKeyHandle {
			handle := key.internal_handle_
			jwk.n = base64_url_uint_encode(handle.modulus)
			jwk.e = base64_url_uint_encode(handle.public_exponent)
			jwk.d = base64_url_uint_encode(handle.private_exponent)
			jwk.p = base64_url_uint_encode(handle.prime1)
			jwk.q = base64_url_uint_encode(handle.prime2)
			jwk.dp = base64_url_uint_encode(handle.exponent1)
			jwk.dq = base64_url_uint_encode(handle.exponent2)
			jwk.qi = base64_url_uint_encode(handle.coefficient)
		}
		else { panic('Invalid RSA handle') }
	}
	return jwk
}

fn export_rsa_key(format KeyFormat, key &CryptoKey) ![]u8 {
	if format == .spki {
		if key.type_ != .public_key { return error('InvalidAccessError: Key is not public') }
		return export_rsa_der(key.internal_handle_, false)
	}
	if format == .pkcs8 {
		if key.type_ != .private_key { return error('InvalidAccessError: Key is not private') }
		return export_rsa_der(key.internal_handle_, true)
	}
	if format == .jwk { return export_rsa_jwk(key)!.to_json().bytes() }
	return error('NotSupportedError: Exporting to format ${key_format_to_string(format)} is not supported')
}
