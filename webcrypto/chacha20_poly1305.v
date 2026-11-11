// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import crypto.rand

fn chacha20_poly1305_crypt(params AeadParams, key &CryptoKey, input []u8, decrypt bool) ![]u8 {
	if params.iv.len != 12 { return error('OperationError: IV must have a length of 12 bytes') }
	if tag := params.tag_length {
		if tag != 128 { return error('OperationError: tagLength must be 128') }
	}
	if decrypt && input.len < 16 {
		return error('OperationError: Ciphertext must be at least 128 bits')
	}
	aad := params.additional_data or { []u8{} }
	return native_chacha20_poly1305(decrypt, key.handle_, params.iv, input, aad)
}

fn chacha_validate_usages(usages []KeyUsage) ! {
	for usage in usages {
		if usage !in [KeyUsage.encrypt, .decrypt, .wrap_key, .unwrap_key] {
			return error("SyntaxError: Invalid key usage '${key_usage_string(usage)}'")
		}
	}
}

fn generate_chacha_key(extractable bool, usages []KeyUsage) !GeneratedKey {
	chacha_validate_usages(usages)!
	return GeneratedKey{
		key: CryptoKey.create(.secret, extractable, KeyAlgorithm{ name: 'ChaCha20-Poly1305' },
			normalize_key_usages(usages), rand.bytes(32)!)
	}
}

fn import_chacha_key(format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey {
	chacha_validate_usages(usages)!
	mut data := material.clone()
	if format == .raw_secret {
		if data.len != 32 { return error('DataError: Key data must be 256 bits') }
	} else if format == .jwk {
		jwk := decode_json_web_key_dictionary(material)!
		if (jwk.kty or { '' }) != 'oct' { return error('DataError: Invalid key type') }
		data = parse_jwk_symmetric_key(jwk)!
		if data.len != 32 { return error('DataError: Key data must be 256 bits') }
		if alg := jwk.alg {
			if alg != 'C20P' { return error('DataError: Invalid alg field') }
		}
		if usages.len > 0 {
			if use := jwk.use {
				if use != 'enc' { return error('DataError: Invalid use field') }
			}
		}
		validate_jwk_key_ops(jwk, usages)!
		if ext := jwk.ext {
			if !ext && extractable { return error('DataError: Invalid ext field') }
		}
	} else {
		return error('NotSupportedError: Only raw-secret and jwk formats are supported')
	}
	return CryptoKey.create(.secret, false, KeyAlgorithm{ name: 'ChaCha20-Poly1305' }, [], data)
}

fn export_chacha_jwk(key &CryptoKey) JsonWebKey {
	return JsonWebKey{
		kty:     'oct'
		k:       base64url_encode(key.handle_)
		alg:     'C20P'
		key_ops: key.usages.map(key_usage_string(it))
		ext:     key.extractable
	}
}

fn export_chacha_key(format KeyFormat, key &CryptoKey) ![]u8 {
	if format == .raw_secret { return key.handle() }
	if format == .jwk { return export_chacha_jwk(key).to_json().bytes() }
	return error('NotSupportedError: Cannot export to unsupported format')
}
