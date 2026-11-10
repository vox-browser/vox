// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Crypto/SubtleCrypto.{h,cpp}.
module webcrypto

import webidl
import x.json2

pub type ExportKeyResult = JsonWebKey | []u8

fn json_value_to_webidl_value(value json2.Any) webidl.Value {
	return match value {
		string { webidl.string_value(value) }
		bool { webidl.boolean_value(value) }
		[]json2.Any {
			webidl.sequence_value(value.map(json_value_to_webidl_value(it)))
		}
		map[string]json2.Any {
			mut object := map[string]webidl.Value{}
			for name, property in value {
				object[name] = json_value_to_webidl_value(property)
			}
			webidl.object_value(object)
		}
		else { webidl.undefined_value() }
	}
}

pub fn export_key_result_to_js_value(_ string, result ExportKeyResult) !webidl.Value {
	if result is []u8 {
		return webidl.buffer_source_value(webidl.BufferSource.array_buffer(result))
	}
	key := result as JsonWebKey
	return json_value_to_webidl_value(json2.Any(key.to_object()))
}

pub fn export_key_result_to_bytes(result ExportKeyResult) ![]u8 {
	if result is []u8 {
		return result.clone()
	}
	key := result as JsonWebKey
	return key.to_json().bytes()
}

pub fn create_algorithm_dictionary(name string) webidl.Value {
	return webidl.object_value({
		'name': webidl.string_value(name)
	})
}

pub fn key_format_expects_buffer_source(format KeyFormat) bool {
	return format in [.raw, .raw_public, .raw_private, .raw_seed, .raw_secret, .pkcs8, .spki]
}

pub struct GeneratedKey {
pub:
	key  ?&CryptoKey
	pair ?CryptoKeyPair
}

pub type KeyGenerationParams = AesKeyGenParams
	| AlgorithmParams
	| EcKeyGenParams
	| HmacKeyGenParams
	| KmacKeyGenParams
	| RsaHashedKeyGenParams

@[heap]
pub struct SubtleCrypto {}

pub fn SubtleCrypto.create() &SubtleCrypto {
	return &SubtleCrypto{}
}

fn normalize_key_usages_for_operation(usages []KeyUsage) []KeyUsage {
	mut normalized := []KeyUsage{cap: usages.len}
	for candidate in [KeyUsage.encrypt, .decrypt, .sign, .verify, .derive_key, .derive_bits, .wrap_key,
		.unwrap_key, .encapsulate_key, .encapsulate_bits, .decapsulate_key, .decapsulate_bits] {
		if candidate in usages {
			normalized << candidate
		}
	}
	return normalized
}

fn validate_jwk_key_ops(jwk JsonWebKey, usages []KeyUsage) ! {
	operations := jwk.key_ops or { return }
	mut seen := map[string]bool{}
	for operation in operations {
		if seen[operation] {
			return error('DataError: Duplicate key operation: ${operation}')
		}
		seen[operation] = true
	}
	is_signing := seen['sign'] || seen['verify']
	is_encryption := seen['encrypt'] || seen['decrypt']
	is_wrapping := seen['wrapKey'] || seen['unwrapKey']
	mut operation_type_count := 0
	if is_signing {
		operation_type_count++
	}
	if is_encryption {
		operation_type_count++
	}
	if is_wrapping {
		operation_type_count++
	}
	if operation_type_count > 1 {
		return error('DataError: Multiple unrelated key operations are specified')
	}
	if use := jwk.use {
		for operation in operations {
			if operation in ['deriveKey', 'deriveBits'] {
				continue
			}
			if use == 'sig' && operation !in ['sign', 'verify'] {
				return error("DataError: use=sig but key_ops does not contain 'sign' or 'verify'")
			}
			if use == 'enc' && operation in ['sign', 'verify'] {
				return error("DataError: use=enc but key_ops contains 'sign' or 'verify'")
			}
		}
	}
	for usage in usages {
		if key_usage_string(usage) !in operations {
			return error('DataError: Missing key_ops usage: ${key_usage_string(usage)}')
		}
	}
}

const digest_algorithms = ['SHA-1', 'SHA-256', 'SHA-384', 'SHA-512', 'SHA3-256', 'SHA3-384', 'SHA3-512',
	'cSHAKE128', 'cSHAKE256']
const encryption_algorithms = ['RSA-OAEP', 'AES-CTR', 'AES-CBC', 'AES-GCM', 'ChaCha20-Poly1305',
	'AES-OCB']
const signing_algorithms = ['RSASSA-PKCS1-v1_5', 'RSA-PSS', 'ECDSA', 'HMAC', 'Ed25519', 'Ed448',
	'ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87', 'KMAC128', 'KMAC256']
const generation_algorithms = ['RSASSA-PKCS1-v1_5', 'RSA-PSS', 'RSA-OAEP', 'ECDSA', 'ECDH', 'AES-CTR',
	'AES-CBC', 'AES-GCM', 'AES-KW', 'HMAC', 'X25519', 'X448', 'Ed25519', 'Ed448', 'ML-DSA-44',
	'ML-DSA-65', 'ML-DSA-87', 'ML-KEM-512', 'ML-KEM-768', 'ML-KEM-1024', 'ChaCha20-Poly1305', 'AES-OCB',
	'KMAC128', 'KMAC256', 'MLKEM768-P256', 'MLKEM768-X25519', 'MLKEM1024-P384']
const import_algorithms = ['RSASSA-PKCS1-v1_5', 'RSA-PSS', 'RSA-OAEP', 'ECDSA', 'ECDH', 'AES-CTR',
	'AES-CBC', 'AES-GCM', 'AES-KW', 'HMAC', 'HKDF', 'PBKDF2', 'X25519', 'X448', 'Ed25519', 'Ed448',
	'ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87', 'ML-KEM-512', 'ML-KEM-768', 'ML-KEM-1024', 'Argon2d',
	'Argon2i', 'Argon2id', 'ChaCha20-Poly1305', 'AES-OCB', 'KMAC128', 'KMAC256', 'MLKEM768-P256', 'MLKEM768-X25519', 'MLKEM1024-P384']
const export_algorithms = ['RSASSA-PKCS1-v1_5', 'RSA-PSS', 'RSA-OAEP', 'ECDSA', 'ECDH', 'AES-CTR',
	'AES-CBC', 'AES-GCM', 'AES-KW', 'HMAC', 'X25519', 'X448', 'Ed25519', 'Ed448', 'ML-DSA-44',
	'ML-DSA-65', 'ML-DSA-87', 'ML-KEM-512', 'ML-KEM-768', 'ML-KEM-1024', 'ChaCha20-Poly1305', 'AES-OCB',
	'KMAC128', 'KMAC256', 'MLKEM768-P256', 'MLKEM768-X25519', 'MLKEM1024-P384']
const derive_algorithms = ['ECDH', 'HKDF', 'PBKDF2', 'X25519', 'X448', 'Argon2d', 'Argon2i', 'Argon2id']
const key_length_algorithms = ['AES-CTR', 'AES-CBC', 'AES-GCM', 'AES-KW', 'HMAC', 'HKDF', 'PBKDF2',
	'Argon2d', 'Argon2i', 'Argon2id', 'ChaCha20-Poly1305', 'AES-OCB', 'KMAC128', 'KMAC256']
const encapsulation_algorithms = ['ML-KEM-512', 'ML-KEM-768', 'ML-KEM-1024', 'MLKEM768-P256', 'MLKEM768-X25519', 'MLKEM1024-P384']

pub fn supported_algorithms_for_operation(operation string) []string {
	return match operation {
		'encrypt', 'decrypt' { encryption_algorithms.clone() }
		'sign', 'verify' { signing_algorithms.clone() }
		'digest' { digest_algorithms.clone() }
		'deriveBits' { derive_algorithms.clone() }
		'wrapKey', 'unwrapKey' { ['AES-KW'] }
		'generateKey' { generation_algorithms.clone() }
		'importKey' { import_algorithms.clone() }
		'exportKey' { export_algorithms.clone() }
		'get key length' { key_length_algorithms.clone() }
		'encapsulate', 'decapsulate' { encapsulation_algorithms.clone() }
		else { []string{} }
	}
}

pub fn normalize_an_algorithm(name string, operation string) !string {
	for registered_name in supported_algorithms_for_operation(operation) {
		if registered_name.to_lower() == name.to_lower() {
			return registered_name
		}
	}
	return error("NotSupportedError: Algorithm '${name}' is not supported for operation '${operation}'")
}

pub fn canonical_algorithm_name(name string) !string {
	for operation in ['encrypt', 'sign', 'digest', 'deriveBits', 'generateKey', 'importKey', 'exportKey',
		'get key length', 'encapsulate'] {
		for registered_name in supported_algorithms_for_operation(operation) {
			if registered_name.to_lower() == name.to_lower() {
				return registered_name
			}
		}
	}
	return error('NotSupportedError: Algorithm is not registered: ${name}')
}

fn validate_operation_key(key &CryptoKey, algorithm string, usage KeyUsage) ! {
	if key.algorithm_name() != algorithm {
		return error('InvalidAccessError: Algorithm mismatch')
	}
	if !key.permits(usage) {
		return error('InvalidAccessError: Key does not support ${key_usage_string(usage)}')
	}
}

pub type DigestParams = CShakeParams | string

pub fn (subtle_crypto &SubtleCrypto) digest(algorithm DigestParams, data []u8) ![]u8 {
	_ = subtle_crypto
	name := match algorithm {
		CShakeParams { algorithm.name }
		string { algorithm }
	}
	normalized := normalize_an_algorithm(name, 'digest')!
	if algorithm is CShakeParams {
		return CShake.create().digest(CShakeParams{ ...algorithm, name: normalized }, data)
	}
	if normalized in ['cSHAKE128', 'cSHAKE256'] {
		return error('TypeError: outputLength is required')
	}
	return digest_bytes(normalized, data)
}

pub fn (subtle_crypto &SubtleCrypto) encrypt(params EncryptionParams, key &CryptoKey, data []u8) ![]u8 {
	_ = subtle_crypto
	name := match params {
		AeadParams { params.name }
		AesCbcParams { params.name }
		AesCtrParams { params.name }
		AesGcmParams { params.name }
		RsaOaepParams { params.name }
		AlgorithmParams { params.name }
	}
	normalized := normalize_an_algorithm(name, 'encrypt')!
	validate_operation_key(key, normalized, .encrypt)!
	return encrypt_bytes(params, key, data)
}

pub fn (subtle_crypto &SubtleCrypto) decrypt(params EncryptionParams, key &CryptoKey, data []u8) ![]u8 {
	_ = subtle_crypto
	name := match params {
		AeadParams { params.name }
		AesCbcParams { params.name }
		AesCtrParams { params.name }
		AesGcmParams { params.name }
		RsaOaepParams { params.name }
		AlgorithmParams { params.name }
	}
	normalized := normalize_an_algorithm(name, 'decrypt')!
	validate_operation_key(key, normalized, .decrypt)!
	return decrypt_bytes(params, key, data)
}

pub type SigningParams = EcdsaParams | Ed448Params | KmacParams | RsaPssParams | string

fn signing_algorithm_name(algorithm SigningParams) string {
	return match algorithm {
		KmacParams { algorithm.name }
		Ed448Params { algorithm.name }
		RsaPssParams { algorithm.name }
		EcdsaParams { algorithm.name }
		string { algorithm }
	}
}

pub fn (subtle_crypto &SubtleCrypto) sign(algorithm SigningParams, key &CryptoKey, data []u8) ![]u8 {
	_ = subtle_crypto
	normalized := normalize_an_algorithm(signing_algorithm_name(algorithm), 'sign')!
	validate_operation_key(key, normalized, .sign)!
	if algorithm is EcdsaParams { return ecdsa_sign(EcdsaParams{ ...algorithm, name: normalized, hash: normalize_an_algorithm(algorithm.hash, 'digest')! }, key, data) }
	if normalized == 'ECDSA' { return error('TypeError: hash is required') }
	if algorithm is RsaPssParams { return RSAPSS.create().sign(RsaPssParams{ ...algorithm, name: normalized }, key, data) }
	if normalized == 'RSA-PSS' { return error('TypeError: saltLength is required') }
	if algorithm is KmacParams {
		return KMAC.create().sign(KmacParams{ ...algorithm, name: normalized }, key, data)
	}
	if algorithm is Ed448Params {
		if normalized.starts_with('ML-DSA-') { return MLDSA.create().sign(Ed448Params{ ...algorithm, name: normalized }, key, data) }
		if normalized == 'Ed448' { return ED448.create().sign(Ed448Params{ ...algorithm, name: normalized }, key, data) }
	}
	if normalized in ['KMAC128', 'KMAC256'] { return error('TypeError: outputLength is required') }
	return match normalized {
		'HMAC' { hmac_sign(key, data)! }
		'RSASSA-PKCS1-v1_5' { rsa_sign(key, data, false, 0)! }
		'Ed25519' { ed25519_sign(key, data)! }
		'Ed448' { ED448.create().sign(Ed448Params{}, key, data)! }
		'ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87' { MLDSA.create().sign(Ed448Params{ name: normalized }, key, data)! }
		else { error('NotSupportedError: ${normalized} signing backend is unavailable') }
	}
}

pub fn (subtle_crypto &SubtleCrypto) verify(algorithm SigningParams, key &CryptoKey, signature []u8, data []u8) !bool {
	_ = subtle_crypto
	normalized := normalize_an_algorithm(signing_algorithm_name(algorithm), 'verify')!
	validate_operation_key(key, normalized, .verify)!
	if algorithm is EcdsaParams { return ecdsa_verify(EcdsaParams{ ...algorithm, name: normalized, hash: normalize_an_algorithm(algorithm.hash, 'digest')! }, key, signature, data) }
	if normalized == 'ECDSA' { return error('TypeError: hash is required') }
	if algorithm is RsaPssParams { return RSAPSS.create().verify(RsaPssParams{ ...algorithm, name: normalized }, key, signature, data) }
	if normalized == 'RSA-PSS' { return error('TypeError: saltLength is required') }
	if algorithm is KmacParams {
		return KMAC.create().verify(KmacParams{ ...algorithm, name: normalized }, key, signature, data)
	}
	if algorithm is Ed448Params {
		if normalized.starts_with('ML-DSA-') { return MLDSA.create().verify(Ed448Params{ ...algorithm, name: normalized }, key, signature, data) }
		if normalized == 'Ed448' { return ED448.create().verify(Ed448Params{ ...algorithm, name: normalized }, key, signature, data) }
	}
	if normalized in ['KMAC128', 'KMAC256'] { return error('TypeError: outputLength is required') }
	return match normalized {
		'HMAC' { hmac_verify(key, signature, data)! }
		'RSASSA-PKCS1-v1_5' { rsa_verify(key, signature, data, false, 0)! }
		'Ed25519' { ed25519_verify(key, signature, data)! }
		'Ed448' { ED448.create().verify(Ed448Params{}, key, signature, data)! }
		'ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87' { MLDSA.create().verify(Ed448Params{ name: normalized }, key, signature, data)! }
		else { error('NotSupportedError: ${normalized} verification backend is unavailable') }
	}
}

pub fn (subtle_crypto &SubtleCrypto) generate_key(params KeyGenerationParams, extractable bool, usages []KeyUsage) !GeneratedKey {
	_ = subtle_crypto
	name := match params {
		AesKeyGenParams { params.name }
		HmacKeyGenParams { params.name }
		KmacKeyGenParams { params.name }
		RsaHashedKeyGenParams { params.name }
		EcKeyGenParams { params.name }
		AlgorithmParams { params.name }
	}
	normalized := normalize_an_algorithm(name, 'generateKey')!
	normalized_usages := normalize_key_usages_for_operation(usages)
    if params is AesKeyGenParams && normalized in ['AES-CBC', 'AES-CTR', 'AES-GCM', 'AES-KW', 'AES-OCB'] {
        key := generate_aes_key(AesKeyGenParams{ ...params, name: normalized }, extractable, normalized_usages)!
        if normalized_usages.len == 0 { return error('SyntaxError: usages must not be empty') }
        return GeneratedKey{ key: key }
    }

    if normalized in ['KMAC128', 'KMAC256'] {
        actual_params := if params is KmacKeyGenParams { KmacKeyGenParams{ ...params, name: normalized } } else { KmacKeyGenParams{ name: normalized } }
        generated := KMAC.create().generate_key(actual_params, extractable, normalized_usages)!
        if normalized_usages.len == 0 { return error('SyntaxError: usages must not be empty') }
        return generated
    }

	return match params {
        EcKeyGenParams {
            generated := generate_ec_key(EcKeyGenParams{ ...params, name: normalized }, extractable, normalized_usages)!
            pair := generated.pair or { return error('OperationError: Missing key pair') }
            if pair.private_key.usages.len == 0 { return error('SyntaxError: usages must not be empty') }
            generated
        }
        RsaHashedKeyGenParams {
            hash := normalize_an_algorithm(params.hash, 'digest')!
            generated := generate_rsa_key(RsaHashedKeyGenParams{ ...params, name: normalized, hash: hash }, extractable, normalized_usages)!
            pair := generated.pair or { return error('OperationError: Missing key pair') }
            if pair.private_key.usages.len == 0 { return error('SyntaxError: usages must not be empty') }
            generated
        }
		KmacKeyGenParams {
			KMAC.create().generate_key(KmacKeyGenParams{ ...params, name: normalized }, extractable, normalized_usages)!
		}
		AesKeyGenParams {
			GeneratedKey{
				key: generate_aes_key(AesKeyGenParams{
					...params
					name: normalized
				}, extractable, normalized_usages)!
			}
		}
		HmacKeyGenParams {
			key := generate_hmac_key(HmacKeyGenParams{ ...params, hash: normalize_an_algorithm(params.hash, 'digest')! }, extractable, normalized_usages)!
			if normalized_usages.len == 0 { return error('SyntaxError: usages must not be empty') }
			GeneratedKey{ key: key }
		}
		AlgorithmParams {
			if is_hybrid_kem(normalized) { return generate_hybrid_kem(normalized,extractable,normalized_usages) }
			if normalized == 'Ed25519' {
                pair := generate_ed25519_key(extractable, normalized_usages)!
                if pair.private_key.usages.len == 0 { return error('SyntaxError: usages must not be empty') }
                return GeneratedKey{ pair: pair }
			}
            if normalized == 'Ed448' {
				generated := generate_ed448_key(extractable, normalized_usages)!
				pair := generated.pair or { return error('OperationError: Missing key pair') }
				if pair.private_key.usages.len == 0 { return error('SyntaxError: usages must not be empty') }
				return generated
			}
            if normalized.starts_with('ML-DSA-') {
				generated := generate_mldsa_key(AlgorithmParams{ name: normalized }, extractable, normalized_usages)!
				pair := generated.pair or { return error('OperationError: Missing key pair') }
				if pair.private_key.usages.len == 0 { return error('SyntaxError: usages must not be empty') }
				return generated
			}
            if normalized.starts_with('ML-KEM-') {
				generated := generate_mlkem_key(AlgorithmParams{ name: normalized }, extractable, normalized_usages)!
				pair := generated.pair or { return error('OperationError: Missing key pair') }
				if pair.private_key.usages.len == 0 { return error('SyntaxError: usages must not be empty') }
				return generated
			}
            if normalized in ['X25519', 'X448'] {
				generated := generate_exchange_key(normalized, extractable, normalized_usages)!
				pair := generated.pair or { return error('OperationError: Missing key pair') }
				if pair.private_key.usages.len == 0 { return error('SyntaxError: usages must not be empty') }
				return generated
			}
            if normalized in ['KMAC128', 'KMAC256'] {
				return KMAC.create().generate_key(KmacKeyGenParams{ name: normalized }, extractable, normalized_usages)
			}
            if normalized == 'ChaCha20-Poly1305' {
                generated := generate_chacha_key(extractable, normalized_usages)!
                if normalized_usages.len == 0 { return error('SyntaxError: usages must not be empty') }
                return generated
			}
            return error('NotSupportedError: ${normalized} key generation backend is unavailable')
		}
	}
}

pub type ImportKeyParams = EcKeyImportParams | HmacImportParams | KmacImportParams | RsaHashedImportParams | string

fn import_algorithm_name(algorithm ImportKeyParams) string {
	return match algorithm {
		KmacImportParams { algorithm.name }
		HmacImportParams { algorithm.name }
		RsaHashedImportParams { algorithm.name }
		EcKeyImportParams { algorithm.name }
		string { algorithm }
	}
}

fn normalized_kmac_import_params(algorithm ImportKeyParams, normalized string) KmacImportParams {
	if algorithm is KmacImportParams { return KmacImportParams{ ...algorithm, name: normalized } }
	return KmacImportParams{ name: normalized }
}

pub fn (subtle_crypto &SubtleCrypto) import_key(format KeyFormat, material []u8, algorithm ImportKeyParams, extractable bool, usages []KeyUsage, hash_name string) !&CryptoKey {
	_ = subtle_crypto
	normalized := normalize_an_algorithm(import_algorithm_name(algorithm), 'importKey')!
	normalized_usages := normalize_key_usages_for_operation(usages)
    if is_hybrid_kem(normalized) {
        key := import_hybrid_kem(normalized,format,material,extractable,normalized_usages)!
        if key.type_ == .private_key && normalized_usages.len == 0 { return error('SyntaxError: usages must not be empty') }
        return key
    }
    if normalized == 'ChaCha20-Poly1305' {
        // Existing typed raw convenience alias; source AlgorithmMethods and JS
        // importKey support raw-secret and JWK only.
        actual_format := if format == .raw { KeyFormat.raw_secret } else { format }
        mut key := import_chacha_key(actual_format, material, extractable, normalized_usages)!
        if normalized_usages.len == 0 { return error('SyntaxError: usages must not be empty') }
        key.set_extractable(extractable)
        key.set_usages(normalized_usages)
        return key
    }

    if normalized in ['AES-CBC', 'AES-CTR', 'AES-GCM', 'AES-KW'] {
        mut key := import_aes_key(normalized, format, material, extractable, normalized_usages)!
        if normalized_usages.len == 0 { return error('SyntaxError: usages must not be empty') }
        key.set_extractable(extractable)
        key.set_usages(normalized_usages)
        return key
    }

    if normalized == 'HMAC' {
        supplied := if algorithm is HmacImportParams { algorithm } else { HmacImportParams{ hash: hash_name } }
        params := HmacImportParams{ ...supplied, hash: normalize_an_algorithm(supplied.hash, 'digest')! }
        mut key := import_hmac_key(params, format, material, extractable, normalized_usages)!
        if normalized_usages.len == 0 { return error('SyntaxError: usages must not be empty') }
        key.set_extractable(extractable)
        key.set_usages(normalized_usages)
        return key
    }
    if normalized in ['Argon2d', 'Argon2i', 'Argon2id'] {
        mut key := import_argon2_key(normalized, format, material, extractable, normalized_usages)!
        if normalized_usages.len == 0 { return error('SyntaxError: usages must not be empty') }
        key.set_usages(normalized_usages)
        return key
    }
    if normalized in ['HKDF', 'PBKDF2'] {
        mut key := import_kdf_key(normalized, format, material, extractable, normalized_usages)!
        if normalized_usages.len == 0 { return error('SyntaxError: usages must not be empty') }
        key.set_usages(normalized_usages)
        return key
    }
    if normalized in ['ECDSA', 'ECDH'] {
        if algorithm !is EcKeyImportParams { return error('TypeError: namedCurve is required') }
        params := algorithm as EcKeyImportParams
        mut key := import_ec_key(EcKeyImportParams{ ...params, name: normalized }, format, material, extractable, normalized_usages)!
        if key.type_ == .private_key && normalized_usages.len == 0 { return error('SyntaxError: usages must not be empty') }
        key.set_extractable(extractable)
        key.set_usages(normalized_usages)
        return key
    }
    if normalized in ['RSA-OAEP', 'RSA-PSS', 'RSASSA-PKCS1-v1_5'] {
        hash := normalize_an_algorithm(if algorithm is RsaHashedImportParams { algorithm.hash } else { hash_name }, 'digest')!
        mut key := import_rsa_key(RsaHashedImportParams{ name: normalized, hash: hash }, format, material, extractable, normalized_usages)!
        if key.type_ == .private_key && normalized_usages.len == 0 { return error('SyntaxError: usages must not be empty') }
        key.set_extractable(extractable)
        key.set_usages(normalized_usages)
        return key
    }
	if normalized == 'AES-OCB' {
		mut key := import_aes_ocb_key(format, material, extractable, normalized_usages)!
		if normalized_usages.len == 0 { return error('SyntaxError: usages must not be empty') }
        key.set_extractable(extractable)
        key.set_usages(normalized_usages)
		return key
	}
	if normalized in ['KMAC128', 'KMAC256'] {
		mut key := KMAC.create().import_key(normalized_kmac_import_params(algorithm, normalized), format, material, extractable, normalized_usages)!
		if normalized_usages.len == 0 { return error('SyntaxError: usages must not be empty') }
        key.set_extractable(extractable)
        key.set_usages(normalized_usages)
		return key
	}
	if normalized.starts_with('ML-DSA-') {
		mut key := import_mldsa_key(AlgorithmParams{ name: normalized }, format, material, extractable, normalized_usages)!
		if key.type_ == .private_key && normalized_usages.len == 0 { return error('SyntaxError: usages must not be empty') }
		key.set_extractable(extractable)
		key.set_usages(normalized_usages)
		return key
	}
	if normalized.starts_with('ML-KEM-') {
		mut key := import_mlkem_key(AlgorithmParams{ name: normalized }, format, material, extractable, normalized_usages)!
		if key.type_ == .private_key && normalized_usages.len == 0 { return error('SyntaxError: usages must not be empty') }
        key.set_extractable(extractable)
        key.set_usages(normalized_usages)
		return key
	}
	if normalized in ['X25519', 'X448'] {
		mut key := import_exchange_key(normalized, format, material, extractable, normalized_usages)!
		if key.type_ == .private_key && normalized_usages.len == 0 { return error('SyntaxError: usages must not be empty') }
        key.set_extractable(extractable)
        key.set_usages(normalized_usages)
		return key
	}
    if normalized == 'Ed25519' {
        mut key := import_ed25519_key(format, material, extractable, normalized_usages)!
        if key.type_ == .private_key && normalized_usages.len == 0 { return error('SyntaxError: usages must not be empty') }
        key.set_usages(normalized_usages)
        return key
    }
	if normalized == 'Ed448' {
		mut key := import_ed448_key(format, material, extractable, normalized_usages)!
		if key.type_ == .private_key && normalized_usages.len == 0 { return error('SyntaxError: usages must not be empty') }
        key.set_extractable(extractable)
        key.set_usages(normalized_usages)
		return key
	}
	if normalized_usages.len == 0 {
		return error('SyntaxError: usages must not be empty')
	}
	if format !in [KeyFormat.raw, .raw_secret] {
		return error('NotSupportedError: ${normalized} import requires a raw key in this backend')
	}
	return import_secret_key(normalized, material, extractable, normalized_usages, hash_name)
}

pub fn (subtle_crypto &SubtleCrypto) import_jwk(jwk JsonWebKey, algorithm ImportKeyParams, extractable bool, usages []KeyUsage, hash_name string) !&CryptoKey {
	_ = subtle_crypto
	normalized := normalize_an_algorithm(import_algorithm_name(algorithm), 'importKey')!
	normalized_usages := normalize_key_usages_for_operation(usages)
    if normalized == 'ChaCha20-Poly1305' { return subtle_crypto.import_key(.jwk, jwk.to_json().bytes(), algorithm, extractable, normalized_usages, hash_name) }

    if normalized in ['AES-CBC', 'AES-CTR', 'AES-GCM', 'AES-KW'] { return subtle_crypto.import_key(.jwk, jwk.to_json().bytes(), algorithm, extractable, normalized_usages, hash_name) }

	if normalized == 'Ed25519' { return subtle_crypto.import_key(.jwk, jwk.to_json().bytes(), algorithm, extractable, normalized_usages, hash_name) }
	if normalized == 'HMAC' { return subtle_crypto.import_key(.jwk, jwk.to_json().bytes(), algorithm, extractable, normalized_usages, hash_name) }
	if normalized in ['ECDSA', 'ECDH'] { return subtle_crypto.import_key(.jwk, jwk.to_json().bytes(), algorithm, extractable, normalized_usages, hash_name) }
	if normalized in ['RSA-OAEP', 'RSA-PSS', 'RSASSA-PKCS1-v1_5'] { return subtle_crypto.import_key(.jwk, jwk.to_json().bytes(), algorithm, extractable, normalized_usages, hash_name) }
	if normalized == 'AES-OCB' {
		return subtle_crypto.import_key(.jwk, jwk.to_json().bytes(), algorithm, extractable, normalized_usages, hash_name)
	}
	if normalized in ['KMAC128', 'KMAC256'] {
		return subtle_crypto.import_key(.jwk, jwk.to_json().bytes(), algorithm, extractable, normalized_usages, hash_name)
	}
	if normalized.starts_with('ML-DSA-') { return subtle_crypto.import_key(.jwk, jwk.to_json().bytes(), algorithm, extractable, normalized_usages, hash_name) }
	if normalized.starts_with('ML-KEM-') { return subtle_crypto.import_key(.jwk, jwk.to_json().bytes(), algorithm, extractable, normalized_usages, hash_name) }
	if normalized in ['X25519', 'X448', 'Ed448'] {
		return subtle_crypto.import_key(.jwk, jwk.to_json().bytes(), algorithm, extractable, normalized_usages, hash_name)
	}
	return subtle_crypto.import_key(.jwk, jwk.to_json().bytes(), algorithm, extractable, normalized_usages, hash_name)
}

pub fn (subtle_crypto &SubtleCrypto) export_key(format KeyFormat, key &CryptoKey) ![]u8 {
	_ = subtle_crypto
	normalize_an_algorithm(key.algorithm_name(), 'exportKey')!
    if is_hybrid_kem(key.algorithm_name()) {
        if !key.extractable { return error('InvalidAccessError: Key is not extractable') }
        return export_hybrid_kem(format,key)
    }
    if key.algorithm_name() == 'ChaCha20-Poly1305' {
        if !key.extractable { return error('InvalidAccessError: Key is not extractable') }
        actual_format := if format == .raw { KeyFormat.raw_secret } else { format }
        return export_chacha_key(actual_format, key)
    }

    if key.algorithm_name() in ['AES-CBC', 'AES-CTR', 'AES-GCM', 'AES-KW'] {
        if !key.extractable { return error('InvalidAccessError: Key is not extractable') }
        return export_aes_key(format, key)
    }

    if key.algorithm_name() == 'Ed25519' {
        if !key.extractable { return error('InvalidAccessError: Key is not extractable') }
        // Existing typed V convenience formats; JS AlgorithmMethods stay source-exact.
        if format in [.raw_seed, .raw_private] && key.type_ == .private_key {
            if format == .raw_seed { return key.handle() }
            mut expanded := key.handle()
            expanded << native_edwards_public('Ed25519', expanded)!
            return expanded
        }
        return export_ed25519_key(format, key)
    }
    if key.algorithm_name() == 'HMAC' {
        if !key.extractable { return error('InvalidAccessError: Key is not extractable') }
        return export_hmac_key(format, key)
    }
	if key.algorithm_name() in ['ECDSA', 'ECDH'] {
		if !key.extractable { return error('InvalidAccessError: Key is not extractable') }
		return export_ec_key(format, key)
	}
	if key.algorithm_name() in ['RSA-OAEP', 'RSA-PSS', 'RSASSA-PKCS1-v1_5'] {
		if !key.extractable { return error('InvalidAccessError: Key is not extractable') }
		return export_rsa_key(format, key)
	}
	if key.algorithm_name().starts_with('ML-DSA-') {
		if !key.extractable { return error('InvalidAccessError: Key is not extractable') }
		return export_mldsa_key(format, key)
	}
	if key.algorithm_name().starts_with('ML-KEM-') {
		if !key.extractable { return error('InvalidAccessError: Key is not extractable') }
		return export_mlkem_key(format, key)
	}
	if key.algorithm_name() == 'Ed448' {
		if !key.extractable { return error('InvalidAccessError: Key is not extractable') }
		return export_ed448_key(format, key)
	}
	if key.algorithm_name() in ['X25519', 'X448'] {
		if !key.extractable { return error('InvalidAccessError: Key is not extractable') }
		return export_exchange_key(key.algorithm_name(), format, key)
	}
	if key.algorithm_name() == 'AES-OCB' {
		if !key.extractable { return error('InvalidAccessError: Key is not extractable') }
		return export_aes_ocb_key(format, key)
	}
	if key.algorithm_name() in ['KMAC128', 'KMAC256'] {
		if !key.extractable { return error('InvalidAccessError: Key is not extractable') }
		return KMAC.create().export_key(format, key)
	}
	if format !in [.raw, .raw_public, .raw_private, .raw_seed, .raw_secret] {
		return error('NotSupportedError: This typed boundary exports raw key material')
	}
	return export_raw_key(key)
}

pub fn (subtle_crypto &SubtleCrypto) export_jwk(key &CryptoKey) !JsonWebKey {
	_ = subtle_crypto
	normalize_an_algorithm(key.algorithm_name(), 'exportKey')!
	if !key.extractable {
		return error('InvalidAccessError: Key is not extractable')
	}
    if is_hybrid_kem(key.algorithm_name()) { return export_hybrid_kem_jwk(key) }
    if key.algorithm_name() in ['AES-CBC', 'AES-CTR', 'AES-GCM', 'AES-KW'] { return export_aes_jwk(key) }
    if key.algorithm_name() == 'ChaCha20-Poly1305' { return export_chacha_jwk(key) }
	if key.algorithm_name() == 'Ed25519' { return export_ed25519_jwk(key) }
	if key.algorithm_name() == 'HMAC' { return export_hmac_jwk(key) }
	if key.algorithm_name() in ['ECDSA', 'ECDH'] { return export_ec_jwk(key) }
	if key.algorithm_name() in ['RSA-OAEP', 'RSA-PSS', 'RSASSA-PKCS1-v1_5'] { return export_rsa_jwk(key) }
	if key.algorithm_name() in ['KMAC128', 'KMAC256'] {
		return JsonWebKey.parse(KMAC.create().export_key(.jwk, key)!)
	}
	if key.algorithm_name() == 'AES-OCB' {
		return JsonWebKey.parse(export_aes_ocb_key(.jwk, key)!)
	}
	if key.algorithm_name().starts_with('ML-DSA-') { return export_mldsa_jwk(key) }
	if key.algorithm_name().starts_with('ML-KEM-') { return export_mlkem_jwk(key) }
	if key.algorithm_name() == 'Ed448' { return export_ed448_jwk(key) }
	if key.algorithm_name() in ['X25519', 'X448'] { return export_exchange_jwk(key.algorithm_name(), key) }
	return error('NotSupportedError: Invalid key format')
}

pub fn (subtle_crypto &SubtleCrypto) derive_bits(params DeriveParams, base_key &CryptoKey, length_bits ?u32) ![]u8 {
	_ = subtle_crypto
	name := match params {
		HkdfParams { params.name }
		Pbkdf2Params { params.name }
		Argon2Params { params.name }
		EcdhKeyDeriveParams { params.name }
	}
	normalized := normalize_an_algorithm(name, 'deriveBits')!
	if params is Argon2Params {
		validate_operation_key(base_key, normalized, .derive_bits)!
		return argon2_derive_bits(Argon2Params{ ...params, name: normalized }, base_key, length_bits)
	}
	if params is HkdfParams {
		hash := normalize_an_algorithm(params.hash, 'digest')!
		validate_operation_key(base_key, normalized, .derive_bits)!
		return hkdf_derive_bits(HkdfParams{ ...params, name: normalized, hash: hash }, base_key, length_bits)
	}
	if params is Pbkdf2Params {
		hash := normalize_an_algorithm(params.hash, 'digest')!
		validate_operation_key(base_key, normalized, .derive_bits)!
		return pbkdf2_derive_bits(Pbkdf2Params{ ...params, name: normalized, hash: hash }, base_key, length_bits)
	}
	if params is EcdhKeyDeriveParams {
		validate_operation_key(base_key, normalized, .derive_bits)!
		if normalized in ['X25519', 'X448'] { return derive_exchange_bits(normalized, EcdhKeyDeriveParams{ ...params, name: normalized }, base_key, length_bits) }
		if normalized == 'ECDH' { return ecdh_derive_bits(EcdhKeyDeriveParams{ ...params, name: normalized }, base_key, length_bits) }
		return error('NotSupportedError: Derivation backend is unavailable for ${normalized}')
	}
	return derive_bits_bytes(params, base_key, length_bits or { return error('OperationError: length is required') })
}

pub fn (subtle_crypto &SubtleCrypto) derive_key(params DeriveParams, base_key &CryptoKey, derived_algorithm string, derived_length u16, extractable bool, usages []KeyUsage) !&CryptoKey {
	if usages.len == 0 {
		return error('SyntaxError: usages must not be empty')
	}
	name := match params {
		HkdfParams { params.name }
		Pbkdf2Params { params.name }
		Argon2Params { params.name }
		EcdhKeyDeriveParams { params.name }
	}
	normalized := normalize_an_algorithm(name, 'deriveBits')!
	if normalized != base_key.algorithm_name() || !base_key.permits(.derive_key) {
		return error('InvalidAccessError: Key does not support deriving keys')
	}
	normalized_derived_algorithm := normalize_an_algorithm(derived_algorithm, 'get key length')!
	if normalized_derived_algorithm.starts_with('AES-') && derived_length !in [
		u16(128),
		192,
		256,
	] {
		return error('OperationError: Invalid derived AES key length')
	}
	bits := derive_bits_bytes_for_usage(params, base_key, u32(derived_length), .derive_key)!
	return subtle_crypto.import_key(.raw, bits, derived_algorithm, extractable,
		normalize_key_usages_for_operation(usages), '')
}

fn (subtle_crypto &SubtleCrypto) export_key_bytes_for_wrapping(format KeyFormat, key &CryptoKey) ![]u8 {
	if format == .jwk {
		return subtle_crypto.export_jwk(key)!.to_json().bytes()
	}
	if !key_format_expects_buffer_source(format) {
		return error('NotSupportedError: Unsupported wrapped key format')
	}
	return subtle_crypto.export_key(format, key)
}

fn (subtle_crypto &SubtleCrypto) import_unwrapped_key(format KeyFormat, bytes []u8, algorithm string, extractable bool, usages []KeyUsage, hash_name string) !&CryptoKey {
	if format == .jwk {
		return subtle_crypto.import_jwk(JsonWebKey.parse(bytes)!, algorithm, extractable, usages, hash_name)
	}
	if !key_format_expects_buffer_source(format) {
		return error('NotSupportedError: Unsupported unwrapped key format')
	}
	return subtle_crypto.import_key(format, bytes, algorithm, extractable, usages, hash_name)
}

pub type WrappingParams = AeadParams
	| AesCbcParams
	| AesCtrParams
	| AesGcmParams
	| AlgorithmParams
	| RsaOaepParams
	| string

fn wrapping_algorithm_name(algorithm WrappingParams) string {
	return match algorithm {
		AeadParams { algorithm.name }
		AesCbcParams { algorithm.name }
		AesCtrParams { algorithm.name }
		AesGcmParams { algorithm.name }
		RsaOaepParams { algorithm.name }
		AlgorithmParams { algorithm.name }
		string { algorithm }
	}
}

fn wrapping_encryption_params(algorithm WrappingParams, normalized string) !EncryptionParams {
	return match algorithm {
		AeadParams { EncryptionParams(AeadParams{ ...algorithm, name: normalized }) }
		AesCbcParams { EncryptionParams(AesCbcParams{ ...algorithm, name: normalized }) }
		AesCtrParams { EncryptionParams(AesCtrParams{ ...algorithm, name: normalized }) }
		AesGcmParams { EncryptionParams(AesGcmParams{ ...algorithm, name: normalized }) }
		RsaOaepParams { EncryptionParams(RsaOaepParams{ ...algorithm, name: normalized }) }
		else {
			if normalized == 'RSA-OAEP' { return EncryptionParams(RsaOaepParams{}) }
			return error('TypeError: Required encryption parameters are missing')
		}
	}
}

pub fn (subtle_crypto &SubtleCrypto) wrap_key(format KeyFormat, key &CryptoKey, wrapping_key &CryptoKey, algorithm WrappingParams) ![]u8 {
	name := wrapping_algorithm_name(algorithm)
	// SubtleCrypto.cpp retries normalization for encrypt if wrapKey is absent.
	normalized := normalize_an_algorithm(name, 'wrapKey') or { normalize_an_algorithm(name, 'encrypt')! }
	validate_operation_key(wrapping_key, normalized, .wrap_key)!
	plain_key := subtle_crypto.export_key_bytes_for_wrapping(format, key)!
	if normalized == 'AES-KW' { return aes_key_wrap(wrapping_key, plain_key) }
	return encrypt_bytes(wrapping_encryption_params(algorithm, normalized)!, wrapping_key, plain_key)
}

pub fn (subtle_crypto &SubtleCrypto) unwrap_key(format KeyFormat, wrapped_key []u8, unwrapping_key &CryptoKey, algorithm WrappingParams, unwrapped_algorithm string, extractable bool, usages []KeyUsage, hash_name string) !&CryptoKey {
	name := wrapping_algorithm_name(algorithm)
	normalized := normalize_an_algorithm(name, 'unwrapKey') or { normalize_an_algorithm(name, 'decrypt')! }
	normalize_an_algorithm(unwrapped_algorithm, 'importKey')!
	validate_operation_key(unwrapping_key, normalized, .unwrap_key)!
	plain_key := if normalized == 'AES-KW' {
		aes_key_unwrap(unwrapping_key, wrapped_key)!
	} else {
		decrypt_bytes(wrapping_encryption_params(algorithm, normalized)!, unwrapping_key, wrapped_key)!
	}
	return subtle_crypto.import_unwrapped_key(format, plain_key, unwrapped_algorithm, extractable, normalize_key_usages_for_operation(usages), hash_name)
}

pub fn (subtle_crypto &SubtleCrypto) encapsulate_bits(algorithm string, key &CryptoKey) !EncapsulatedBits {
	_ = subtle_crypto
	normalized := normalize_an_algorithm(algorithm, 'encapsulate')!
	validate_operation_key(key, normalized, .encapsulate_bits)!
	return MLKEM.create().encapsulate(AlgorithmParams{ name: normalized }, key)
}

pub fn (subtle_crypto &SubtleCrypto) decapsulate_bits(algorithm string, key &CryptoKey, ciphertext []u8) ![]u8 {
	_ = subtle_crypto
	_ = ciphertext
	normalized := normalize_an_algorithm(algorithm, 'decapsulate')!
	validate_operation_key(key, normalized, .decapsulate_bits)!
	return MLKEM.create().decapsulate(AlgorithmParams{ name: normalized }, key, ciphertext)
}

// SubtleCrypto.cpp's KEM key methods invoke the algorithm's import operation
// directly; their shared-key usages are not checked by public importKey.
fn import_kem_shared_secret(name string, bytes []u8, extractable bool, usages []KeyUsage) !&CryptoKey {
	if name == 'AES-OCB' { return import_aes_ocb_key(.raw_secret, bytes, extractable, usages) }
	if name in ['KMAC128', 'KMAC256'] {
		return KMAC.create().import_key(KmacImportParams{ name: name }, .raw_secret, bytes, extractable, usages)
	}
	return import_secret_key(name, bytes, extractable, usages, '')
}

pub fn (subtle_crypto &SubtleCrypto) encapsulate_key(algorithm string, key &CryptoKey,
	shared_key_algorithm string, extractable bool, usages []KeyUsage) !EncapsulatedKey {
	normalized := normalize_an_algorithm(algorithm, 'encapsulate')!
	validate_operation_key(key, normalized, .encapsulate_key)!
	bits := MLKEM.create().encapsulate(AlgorithmParams{ name: normalized }, key)!
	shared_key_bits := bits.shared_key or {
		return error('OperationError: Encapsulation produced no shared key')
	}
	shared_name := normalize_an_algorithm(shared_key_algorithm, 'importKey')!
    normalized_usages := normalize_key_usages_for_operation(usages)
	mut shared_key := import_kem_shared_secret(shared_name, shared_key_bits, extractable, normalized_usages)!
    shared_key.set_extractable(extractable)
    shared_key.set_usages(normalized_usages)
	return EncapsulatedKey{
		shared_key: shared_key
		ciphertext: bits.ciphertext
	}
}

pub fn (subtle_crypto &SubtleCrypto) decapsulate_key(algorithm string, key &CryptoKey,
	ciphertext []u8, shared_key_algorithm string, extractable bool,
	usages []KeyUsage) !&CryptoKey {
	normalized := normalize_an_algorithm(algorithm, 'decapsulate')!
	validate_operation_key(key, normalized, .decapsulate_key)!
	bits := MLKEM.create().decapsulate(AlgorithmParams{ name: normalized }, key, ciphertext)!
	shared_name := normalize_an_algorithm(shared_key_algorithm, 'importKey')!
    normalized_usages := normalize_key_usages_for_operation(usages)
    mut shared_key := import_kem_shared_secret(shared_name, bits, extractable, normalized_usages)!
    shared_key.set_extractable(extractable)
    shared_key.set_usages(normalized_usages)
    return shared_key
}
