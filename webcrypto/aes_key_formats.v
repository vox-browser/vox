// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import crypto.rand

// The AES algorithms share these operations but differ in supported formats
// and malformed-handle export behavior.
fn aes_validate_usages(name string, usages []KeyUsage) ! {
	allowed := if name == 'AES-KW' { [KeyUsage.wrap_key, .unwrap_key] } else { [
			KeyUsage.encrypt,
			.decrypt,
			.wrap_key,
			.unwrap_key,
		] }
	for usage in usages {
		if usage !in allowed {
			return error("SyntaxError: Invalid key usage '${key_usage_string(usage)}'")
		}
	}
}

fn generate_source_aes_key(params AesKeyGenParams, extractable bool, usages []KeyUsage) !&CryptoKey {
	aes_validate_usages(params.name, usages)!
	if params.length !in [u16(128), 192, 256] {
		return error('OperationError: Cannot create ${params.name} key with unusual amount of ${params.length} bits')
	}
	material := rand.bytes(int(params.length / 8))!
	return CryptoKey.create(.secret, extractable, AesKeyAlgorithm{
		name:   params.name
		length: params.length
	}, normalize_key_usages(usages), material)
}

fn import_aes_key(name string, format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey {
	aes_validate_usages(name, usages)!
	mut data := material.clone()
	if format in [.raw, .raw_secret] && (name != 'AES-OCB' || format == .raw_secret) {
		bits := data.len * 8
		if bits !in [128, 192, 256] {
			return error("DataError: Invalid key length '${bits}' bits (must be either 128, 192, or 256 bits)")
		}
	} else if format == .jwk {
		jwk := decode_json_web_key_dictionary(material)!
		if (jwk.kty or { '' }) != 'oct' { return error('DataError: Invalid key type') }
		if name in ['AES-CTR', 'AES-GCM'] && jwk.k == none {
			return error("DataError: Missing 'k' field")
		}
		data = parse_jwk_symmetric_key(jwk)!
		bits := data.len * 8
		if bits !in [128, 192, 256] { return error('DataError: Invalid key size: ${bits} bits') }
		if alg := jwk.alg {
			if alg != 'A${bits}${name[4..]}' {
				return error('DataError: Contradictory key size: key has ${bits} bits, but alg specifies non-${bits}-bit algorithm')
			}
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
		if name == 'AES-OCB' { return error('NotSupportedError: Only raw-secret and jwk formats are supported') }
        return error('NotSupportedError: Only raw and jwk formats are supported')
	}
	// The common SubtleCrypto import boundary installs extractable and usages.
	return CryptoKey.create(.secret, false, AesKeyAlgorithm{ name: name, length: u16(data.len * 8) },
		[], data)
}

fn export_aes_jwk(key &CryptoKey) !JsonWebKey {
	bits := key.handle_.len * 8
	mut alg := ?string(none)
	if bits in [128, 192, 256] {
		alg = 'A${bits}${key.algorithm_name()[4..]}'
	} else if key.algorithm_name() == 'AES-CBC' {
		return error('OperationError: unclear key size')
	}
	return JsonWebKey{
		kty:     'oct'
		k:       base64url_encode(key.handle_)
		alg:     alg
		key_ops: key.usages.map(key_usage_string(it))
		ext:     key.extractable
	}
}

fn export_aes_key(format KeyFormat, key &CryptoKey) ![]u8 {
	if format in [.raw, .raw_secret] && (key.algorithm_name() != 'AES-OCB' || format == .raw_secret) { return key.handle() }
	if format == .jwk { return export_aes_jwk(key)!.to_json().bytes() }
	return error('NotSupportedError: Cannot export to unsupported format')
}
