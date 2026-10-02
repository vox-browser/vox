// SPDX-License-Identifier: BSD-2-Clause
// Translation of CryptoAlgorithms.cpp ED448 operation bodies.
module webcrypto

fn validate_ed448_usages(usages []KeyUsage, allowed []KeyUsage) ! {
	for usage in usages {
		if usage !in allowed {
			return error("SyntaxError: Invalid key usage '${key_usage_string(usage)}'")
		}
	}
}

fn generate_ed448_key(extractable bool, usages []KeyUsage) !GeneratedKey {
	validate_ed448_usages(usages, [.sign, .verify])!
	private_bytes := native_edwards_private('Ed448')!
	public_bytes := native_edwards_public('Ed448', private_bytes)!
	return GeneratedKey{
		pair: CryptoKeyPair{
			public_key:  exchange_key('Ed448', false, public_bytes, true, normalize_key_usages_for_operation(usages.filter(it == .verify)))
			private_key: exchange_key('Ed448', true, private_bytes, extractable, normalize_key_usages_for_operation(usages.filter(it == .sign)))
		}
	}
}

fn ed448_sign(params Ed448Params, key &CryptoKey, message []u8) ![]u8 {
	if key.type_ != .private_key { return error('InvalidAccessError: Key is not a private key') }
	context := params.context or { []u8{} }
	if context.len > 255 { return error('OperationError: Context is too long') }
	return native_ed448_sign(key.handle_, message, context)
}

fn ed448_verify(params Ed448Params, key &CryptoKey, signature []u8, message []u8) !bool {
	if key.type_ != .public_key { return error('InvalidAccessError: Key is not a public key') }
	context := params.context or { []u8{} }
	if context.len > 255 { return error('OperationError: Context is too long') }
	return native_ed448_verify(key.handle_, signature, message, context)
}

fn import_ed448_jwk(jwk JsonWebKey, extractable bool, usages []KeyUsage) !&CryptoKey {
	private_key := jwk.d != none
	validate_ed448_usages(usages, if private_key { [KeyUsage.sign] } else { [KeyUsage.verify] })!
	if (jwk.kty or { '' }) != 'OKP' { return error('DataError: Invalid key type') }
	if (jwk.crv or { '' }) != 'Ed448' { return error('DataError: Invalid curve') }
	if alg := jwk.alg {
		if alg !in ['Ed448', 'EdDSA'] { return error('DataError: Invalid algorithm') }
	}
	if usages.len != 0 {
		if use := jwk.use {
			if use != 'sig' { return error('DataError: Invalid key usage') }
		}
	}
	validate_jwk_key_ops(jwk, usages)!
	if ext := jwk.ext {
		if !ext && extractable { return error('DataError: Invalid extractable') }
	}
	public_bytes := base64url_decode(jwk.x or { return error('DataError: Missing x field') })!
	if public_bytes.len != 57 { return error('DataError: Invalid key length') }
	if value := jwk.d {
		private_bytes := base64url_decode(value)!
		if private_bytes.len != 57 { return error('DataError: Invalid key length') }
		if native_edwards_public('Ed448', private_bytes)! != public_bytes {
			return error('DataError: Invalid key pair')
		}
		return exchange_key('Ed448', true, private_bytes, false, [])
	}
	return exchange_key('Ed448', false, public_bytes, false, [])
}

pub fn import_ed448_key(format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey {
	match format {
		.spki, .pkcs8 {
			private_key := format == .pkcs8
			validate_ed448_usages(usages, if private_key {
				[KeyUsage.sign]
			} else {
				[KeyUsage.verify]
			})!
			bytes := parse_okp_der('Ed448', material, private_key) or {
				if err.msg() == 'DataError: Invalid algorithm' {
					return error('DataError: Invalid algorithm identifier')
				}
				return err
			}
			return exchange_key('Ed448', private_key, bytes, false, [])
		}
		.jwk { return import_ed448_jwk(JsonWebKey.parse(material)!, extractable, usages) }
		.raw {
			validate_ed448_usages(usages, [.verify])!
			if material.len != 57 { return error('DataError: Invalid key length') }
			return exchange_key('Ed448', false, material, false, [])
		}
		else { return error('NotSupportedError: Invalid key format') }
	}
}

fn export_ed448_jwk(key &CryptoKey) !JsonWebKey {
	jwk := export_exchange_jwk('Ed448', key)!
	return JsonWebKey{ ...jwk, alg: 'Ed448' }
}

fn export_ed448_key(format KeyFormat, key &CryptoKey) ![]u8 {
	if format == .jwk { return export_ed448_jwk(key)!.to_json().bytes() }
	if format == .raw_public { return error('NotSupportedError: Invalid key format') }
	return export_exchange_key('Ed448', format, key)
}
