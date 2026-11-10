// SPDX-License-Identifier: BSD-2-Clause
// CryptoAlgorithms.cpp HMAC generation, import and export operation bodies.
module webcrypto

import crypto.rand

fn hmac_validate_usages(usages []KeyUsage) ! {
	for usage in usages {
		if usage !in [KeyUsage.sign, .verify] {
			return error("SyntaxError: Invalid key usage '${key_usage_string(usage)}'")
		}
	}
}

pub fn generate_hmac_key(params HmacKeyGenParams, extractable bool, usages []KeyUsage) !&CryptoKey {
	hmac_validate_usages(usages)!
	length := params.length or { u32(hash_block_size(params.hash)! * 8) }
	if length == 0 { return error('OperationError: Invalid length') }
	// The source generate_random_key helper takes u16 and floors bits to bytes.
	material := rand.bytes(int(u16(length) / 8)) or { return error('OperationError: Key generation failed: ${err}') }
	return CryptoKey.create(.secret, extractable, HmacKeyAlgorithm{ name: 'HMAC', hash: params.hash, length: length }, usages, material)
}

fn hmac_jwk_algorithm(hash string) !string {
	return match hash {
		'SHA-1' { 'HS1' }
		'SHA-256' { 'HS256' }
		'SHA-384' { 'HS384' }
		'SHA-512' { 'HS512' }
		else { return error('DataError: Invalid algorithm') }
	}
}

fn import_hmac_key(params HmacImportParams, format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey {
	hmac_validate_usages(usages)!
	mut data := material.clone()
	if format == .jwk {
		jwk := decode_json_web_key_dictionary(material)!
		if (jwk.kty or { '' }) != 'oct' { return error('DataError: Invalid key type') }
		data = parse_jwk_symmetric_key(jwk)!
		expected := hmac_jwk_algorithm(params.hash)!
		if alg := jwk.alg {
			if alg != expected { return error('DataError: Invalid algorithm') }
		}
		if usages.len > 0 {
			if use := jwk.use {
				if use != 'sig' { return error('DataError: Invalid use in JsonWebKey') }
			}
		}
		validate_jwk_key_ops(jwk, usages)!
		if ext := jwk.ext {
			if !ext && extractable { return error('DataError: Invalid ext field') }
		}
	} else if format !in [.raw, .raw_secret] {
		return error('NotSupportedError: Invalid key format')
	}
	mut length := u32(data.len * 8)
	if length == 0 { return error('DataError: No data provided') }
	if requested := params.length {
		if requested > length || requested <= length - 8 {
			return error('DataError: Invalid data size')
		}
		length = requested
	}
	// Upstream slices whole bytes; it drops the trailing fractional byte.
	if data.len > int(length / 8) { data = data[..int(length / 8)].clone() }
	return CryptoKey.create(.secret, false, HmacKeyAlgorithm{ name: 'HMAC', hash: params.hash, length: length }, [], data)
}

fn export_hmac_jwk(key &CryptoKey) !JsonWebKey {
	if key.algorithm !is HmacKeyAlgorithm {
		return error('InvalidAccessError: Key is not an HMAC key')
	}
	algorithm := key.algorithm as HmacKeyAlgorithm
	return JsonWebKey{
		kty:     'oct'
		k:       base64url_encode(key.handle_)
		alg:     hmac_jwk_algorithm(algorithm.hash)!
		key_ops: key.usages.map(key_usage_string(it))
		ext:     key.extractable
	}
}

fn export_hmac_key(format KeyFormat, key &CryptoKey) ![]u8 {
	if format in [.raw, .raw_secret] { return key.handle() }
	if format == .jwk { return export_hmac_jwk(key)!.to_json().bytes() }
	return error('NotSupportedError: Invalid key format')
}
