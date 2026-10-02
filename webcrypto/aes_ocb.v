// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// CryptoAlgorithms.cpp AesOcb operations, using upstream's EVP AES-OCB backend.
module webcrypto

fn aes_ocb_crypt(params AeadParams, key &CryptoKey, data []u8, decrypt bool) ![]u8 {
	if params.iv.len > 15 { return error('OperationError: IV must have a length of 15 bytes') }
	tag_length := params.tag_length or { u8(128) }
	if tag_length !in [u8(64), 96, 128] { return error('OperationError: Invalid tag length') }
	if decrypt && data.len < int(tag_length / 8) {
		return error('OperationError: Ciphertext is less than tagLength bits')
	}
	key_bytes := valid_aes_key(key, 'AES-OCB')!
	return native_aes_ocb(decrypt, key_bytes, data, params.iv, params.additional_data or { []u8{} }, int(tag_length / 8))
}

fn import_aes_ocb_key(format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey {
	validate_usages(usages, [KeyUsage.encrypt, .decrypt, .wrap_key, .unwrap_key])!
	mut data := material.clone()
	if format == .jwk {
		jwk := JsonWebKey.parse(material)!
		if (jwk.kty or { '' }) != 'oct' { return error('DataError: Invalid key type') }
		actual_alg := jwk.alg or { return error("DataError: Missing 'alg' field") }
		data = parse_jwk_symmetric_key(jwk)!
		if data.len !in [16, 24, 32] {
			return error('DataError: Invalid key size: ${data.len * 8} bits')
		}
		if actual_alg != 'A${data.len * 8}OCB' { return error('DataError: Contradictory key size') }
		if usages.len > 0 {
			if use := jwk.use {
				if use != 'enc' { return error('DataError: Invalid use field') }
			}
		}
		validate_jwk_key_ops(jwk, usages)!
		if ext := jwk.ext {
			if !ext && extractable { return error('DataError: Invalid ext field') }
		}
	} else if format == .raw_secret {
		if data.len !in [16, 24, 32] { return error('DataError: Invalid key length') }
	} else {
		return error('NotSupportedError: Only raw-secret and jwk formats are supported')
	}
	return CryptoKey.create(.secret, extractable, AesKeyAlgorithm{ name: 'AES-OCB', length: u16(data.len * 8) }, usages, data)
}

fn export_aes_ocb_key(format KeyFormat, key &CryptoKey) ![]u8 {
	if format == .raw_secret { return key.handle() }
	if format != .jwk { return error('NotSupportedError: Cannot export to unsupported format') }
	return JsonWebKey{
		kty:     'oct'
		k:       base64url_encode(key.handle())
		alg:     'A${key.handle().len * 8}OCB'
		key_ops: key.usages.map(key_usage_string(it))
		ext:     key.extractable
	}.to_json().bytes()
}
