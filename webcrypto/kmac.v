// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// CryptoAlgorithms.cpp KMAC::{sign,verify,generate_key,import_key,export_key}.
module webcrypto

import crypto.rand

fn kmac_validate_usages(usages []KeyUsage) ! {
    for usage in usages {
        if usage !in [KeyUsage.sign, .verify] {
            return error("SyntaxError: Invalid key usage '${key_usage_string(usage)}'")
        }
    }
}

fn kmac_default_length(name string) !u32 {
	return match name {
		'KMAC128' { u32(128) }
		'KMAC256' { u32(256) }
		else { return error('OperationError: Unsupported KMAC algorithm') }
	}
}

fn kmac_sign(params KmacParams, key &CryptoKey, message []u8) ![]u8 {
	return kmac_calculate_mac(params.name, key.handle(), message, params.output_length,
		params.customization or { []u8{} })
}

fn generate_kmac_key(params KmacKeyGenParams, extractable bool, usages []KeyUsage) !&CryptoKey {
	kmac_validate_usages(usages)!
	length := params.length or { kmac_default_length(params.name)! }
	// The upstream shared generate_random_key helper takes u16 bit lengths.
	// Zero-length KMAC keys are valid: avoid asking the OS RNG for zero bytes.
	material := if length == 0 {
		[]u8{}
	} else {
		rand.bytes(int(u16(length) / 8)) or {
			return error('OperationError: Key generation failed: ${err}')
		}
	}
	return CryptoKey.create(.secret, extractable, KmacKeyAlgorithm{ name: params.name, length: length }, usages, material)
}

fn import_kmac_key(params KmacImportParams, format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey {
	kmac_validate_usages(usages)!
	mut data := material.clone()
	if format == .jwk {
		jwk := decode_json_web_key_dictionary(material)!
		if (jwk.kty or { '' }) != 'oct' {
			return error('DataError: Invalid key type')
		}
		data = parse_jwk_symmetric_key(jwk)!
		if alg := jwk.alg {
			expected := if params.name == 'KMAC128' { 'K128' } else { 'K256' }
			if alg != expected { return error('DataError: Invalid alg field for ${params.name}') }
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
	} else if format != .raw_secret {
		return error('NotSupportedError: Only raw-secret and jwk formats are supported')
	}
	mut length := u32(data.len * 8)
	if requested := params.length {
		if requested > length || length - requested >= 8 {
			return error('DataError: Invalid data size')
		}
		length = requested
	}
	// Upstream slices to length / 8 bytes, including a non-byte-aligned length.
	if data.len > int(length / 8) { data = data[..int(length / 8)].clone() }
	return CryptoKey.create(.secret, false, KmacKeyAlgorithm{ name: params.name, length: length }, [], data)
}

fn export_kmac_key(format KeyFormat, key &CryptoKey) ![]u8 {
	if format == .raw_secret { return key.handle() }
	if format != .jwk { return error('NotSupportedError: Cannot export to unsupported format') }
	return JsonWebKey{
		kty:     'oct'
		k:       base64url_encode(key.handle())
		alg:     if key.algorithm_name() == 'KMAC128' { 'K128' } else { 'K256' }
		key_ops: key.usages.map(key_usage_string(it))
		ext:     key.extractable
	}.to_json().bytes()
}
