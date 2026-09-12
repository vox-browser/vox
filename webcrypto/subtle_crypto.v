// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Crypto/SubtleCrypto.{h,cpp}.
module webcrypto

import crypto.rand
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

pub type KeyGenerationParams = AesKeyGenParams | AlgorithmParams | HmacKeyGenParams

@[heap]
pub struct SubtleCrypto {}

pub fn SubtleCrypto.create() &SubtleCrypto {
	return &SubtleCrypto{}
}

fn normalize_key_usages_for_operation(usages []KeyUsage) []KeyUsage {
	mut normalized := []KeyUsage{cap: usages.len}
	for candidate in [KeyUsage.encrypt, .decrypt, .sign, .verify, .derive_key, .derive_bits,
		.wrap_key, .unwrap_key, .encapsulate_key, .encapsulate_bits, .decapsulate_key,
		.decapsulate_bits] {
		for usage in usages {
			if usage == candidate {
				normalized << usage
			}
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
				return error('DataError: use=sig contradicts key_ops')
			}
			if use == 'enc' && operation in ['sign', 'verify'] {
				return error('DataError: use=enc contradicts key_ops')
			}
		}
	}
	for usage in usages {
		if key_usage_string(usage) !in operations {
			return error('DataError: Requested usage is absent from JWK key_ops')
		}
	}
}

fn expected_jwk_algorithm(algorithm string, key_length int, hash_name string) !string {
	return match algorithm {
		'AES-CBC' {
			'A${key_length}CBC'
		}
		'AES-CTR' {
			'A${key_length}CTR'
		}
		'AES-GCM' {
			'A${key_length}GCM'
		}
		'AES-KW' {
			'A${key_length}KW'
		}
		'HMAC' {
			match canonical_hash_name(hash_name)! {
				'SHA-1' { 'HS1' }
				'SHA-256' { 'HS256' }
				'SHA-384' { 'HS384' }
				'SHA-512' { 'HS512' }
				else { return error('DataError: This HMAC hash has no JWK alg value') }
			}
		}
		'Ed25519' {
			'Ed25519'
		}
		'ChaCha20-Poly1305' {
			'C20P'
		}
		else {
			error('NotSupportedError: JWK import is unavailable for ${algorithm}')
		}
	}
}

fn validate_jwk_algorithm_metadata(jwk JsonWebKey, algorithm string, material_length int, hash_name string, usages []KeyUsage) ! {
	expected_algorithm := expected_jwk_algorithm(algorithm, material_length * 8, hash_name)!
	if actual_algorithm := jwk.alg {
		if algorithm == 'Ed25519' {
			if actual_algorithm !in ['Ed25519', 'EdDSA'] {
				return error('DataError: Invalid Ed25519 JWK alg')
			}
		} else if actual_algorithm != expected_algorithm {
			return error('DataError: JWK alg contradicts the key algorithm or length')
		}
	}
	if usages.len > 0 {
		if use := jwk.use {
			expected_use := match algorithm {
				'HMAC' { 'sign' }
				'Ed25519' { 'sig' }
				else { 'enc' }
			}
			if use != expected_use {
				return error('DataError: Invalid JWK use field')
			}
		}
	}
	validate_jwk_key_ops(jwk, usages)!
}

const digest_algorithms = ['SHA-1', 'SHA-256', 'SHA-384', 'SHA-512', 'SHA3-256', 'SHA3-384',
	'SHA3-512', 'cSHAKE128', 'cSHAKE256']
const encryption_algorithms = ['RSA-OAEP', 'AES-CTR', 'AES-CBC', 'AES-GCM', 'ChaCha20-Poly1305',
	'AES-OCB']
const signing_algorithms = ['RSASSA-PKCS1-v1_5', 'RSA-PSS', 'ECDSA', 'HMAC', 'Ed25519', 'Ed448',
	'ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87', 'KMAC128', 'KMAC256']
const generation_algorithms = ['RSASSA-PKCS1-v1_5', 'RSA-PSS', 'RSA-OAEP', 'ECDSA', 'ECDH', 'AES-CTR',
	'AES-CBC', 'AES-GCM', 'AES-KW', 'HMAC', 'X25519', 'X448', 'Ed25519', 'Ed448', 'ML-DSA-44',
	'ML-DSA-65', 'ML-DSA-87', 'ML-KEM-512', 'ML-KEM-768', 'ML-KEM-1024', 'ChaCha20-Poly1305',
	'AES-OCB', 'KMAC128', 'KMAC256']
const import_algorithms = ['RSASSA-PKCS1-v1_5', 'RSA-PSS', 'RSA-OAEP', 'ECDSA', 'ECDH', 'AES-CTR',
	'AES-CBC', 'AES-GCM', 'AES-KW', 'HMAC', 'HKDF', 'PBKDF2', 'X25519', 'X448', 'Ed25519', 'Ed448',
	'ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87', 'ML-KEM-512', 'ML-KEM-768', 'ML-KEM-1024', 'Argon2d',
	'Argon2i', 'Argon2id', 'ChaCha20-Poly1305', 'AES-OCB', 'KMAC128', 'KMAC256']
const export_algorithms = ['RSASSA-PKCS1-v1_5', 'RSA-PSS', 'RSA-OAEP', 'ECDSA', 'ECDH', 'AES-CTR',
	'AES-CBC', 'AES-GCM', 'AES-KW', 'HMAC', 'X25519', 'X448', 'Ed25519', 'Ed448', 'ML-DSA-44',
	'ML-DSA-65', 'ML-DSA-87', 'ML-KEM-512', 'ML-KEM-768', 'ML-KEM-1024', 'ChaCha20-Poly1305',
	'AES-OCB', 'KMAC128', 'KMAC256']
const derive_algorithms = ['ECDH', 'HKDF', 'PBKDF2', 'X25519', 'X448', 'Argon2d', 'Argon2i',
	'Argon2id']
const key_length_algorithms = ['AES-CTR', 'AES-CBC', 'AES-GCM', 'AES-KW', 'HMAC', 'HKDF', 'PBKDF2',
	'Argon2d', 'Argon2i', 'Argon2id', 'ChaCha20-Poly1305', 'AES-OCB', 'KMAC128', 'KMAC256']
const encapsulation_algorithms = ['ML-KEM-512', 'ML-KEM-768', 'ML-KEM-1024']

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
	for operation in ['encrypt', 'sign', 'digest', 'deriveBits', 'generateKey', 'importKey',
		'exportKey', 'get key length', 'encapsulate'] {
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

pub fn (subtle_crypto &SubtleCrypto) digest(algorithm string, data []u8) ![]u8 {
	_ = subtle_crypto
	normalized := normalize_an_algorithm(algorithm, 'digest')!
	return digest_bytes(normalized, data)
}

pub fn (subtle_crypto &SubtleCrypto) encrypt(params EncryptionParams, key &CryptoKey, data []u8) ![]u8 {
	_ = subtle_crypto
	name := match params {
		AeadParams { params.name }
		AesCbcParams { params.name }
		AesCtrParams { params.name }
		AesGcmParams { params.name }
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
		AlgorithmParams { params.name }
	}
	normalized := normalize_an_algorithm(name, 'decrypt')!
	validate_operation_key(key, normalized, .decrypt)!
	return decrypt_bytes(params, key, data)
}

pub fn (subtle_crypto &SubtleCrypto) sign(algorithm string, key &CryptoKey, data []u8) ![]u8 {
	_ = subtle_crypto
	normalized := normalize_an_algorithm(algorithm, 'sign')!
	validate_operation_key(key, normalized, .sign)!
	return match normalized {
		'HMAC' { hmac_sign(key, data)! }
		'Ed25519' { ed25519_sign(key, data)! }
		else { error('NotSupportedError: ${normalized} signing backend is unavailable') }
	}
}

pub fn (subtle_crypto &SubtleCrypto) verify(algorithm string, key &CryptoKey, signature []u8, data []u8) !bool {
	_ = subtle_crypto
	normalized := normalize_an_algorithm(algorithm, 'verify')!
	validate_operation_key(key, normalized, .verify)!
	return match normalized {
		'HMAC' { hmac_verify(key, signature, data)! }
		'Ed25519' { ed25519_verify(key, signature, data)! }
		else { error('NotSupportedError: ${normalized} verification backend is unavailable') }
	}
}

pub fn (subtle_crypto &SubtleCrypto) generate_key(params KeyGenerationParams, extractable bool, usages []KeyUsage) !GeneratedKey {
	_ = subtle_crypto
	name := match params {
		AesKeyGenParams { params.name }
		HmacKeyGenParams { params.name }
		AlgorithmParams { params.name }
	}
	normalized := normalize_an_algorithm(name, 'generateKey')!
	normalized_usages := normalize_key_usages_for_operation(usages)
	if normalized_usages.len == 0
		|| (normalized == 'Ed25519' && KeyUsage.sign !in normalized_usages) {
		return error('SyntaxError: usages must not be empty')
	}
	return match params {
		AesKeyGenParams {
			GeneratedKey{
				key: generate_aes_key(AesKeyGenParams{
					...params
					name: normalized
				}, extractable, normalized_usages)!
			}
		}
		HmacKeyGenParams {
			GeneratedKey{
				key: generate_hmac_key(params, extractable, normalized_usages)!
			}
		}
		AlgorithmParams {
			if normalized == 'Ed25519' {
				GeneratedKey{
					pair: generate_ed25519_key(extractable, normalized_usages)!
				}
			} else if normalized == 'ChaCha20-Poly1305' {
				validate_usages(normalized_usages, [KeyUsage.encrypt, .decrypt, .wrap_key,
					.unwrap_key])!
				GeneratedKey{
					key: CryptoKey.create(.secret, extractable, KeyAlgorithm{
						name: normalized
					}, normalized_usages, rand.bytes(32)!)
				}
			} else {
				return error('NotSupportedError: ${normalized} key generation backend is unavailable')
			}
		}
	}
}

pub fn (subtle_crypto &SubtleCrypto) import_key(format KeyFormat, material []u8, algorithm string, extractable bool, usages []KeyUsage, hash_name string) !&CryptoKey {
	_ = subtle_crypto
	normalized := normalize_an_algorithm(algorithm, 'importKey')!
	normalized_usages := normalize_key_usages_for_operation(usages)
	if normalized == 'Ed25519' {
		if format in [KeyFormat.raw_seed, .raw_private] && normalized_usages.len == 0 {
			return error('SyntaxError: usages must not be empty')
		}
		return import_ed25519_key(format, material, extractable, normalized_usages)
	}
	if normalized == 'Ed448' {
		return import_ed448_key(format, material, extractable, normalized_usages)
	}
	if normalized_usages.len == 0 {
		return error('SyntaxError: usages must not be empty')
	}
	if format !in [KeyFormat.raw, .raw_secret] {
		return error('NotSupportedError: ${normalized} import requires a raw key in this backend')
	}
	return import_secret_key(normalized, material, extractable, normalized_usages, hash_name)
}

pub fn (subtle_crypto &SubtleCrypto) import_jwk(jwk JsonWebKey, algorithm string, extractable bool, usages []KeyUsage, hash_name string) !&CryptoKey {
	_ = subtle_crypto
	normalized := normalize_an_algorithm(algorithm, 'importKey')!
	normalized_usages := normalize_key_usages_for_operation(usages)
	if extractable {
		if jwk_extractable := jwk.ext {
			if !jwk_extractable {
				return error('DataError: JWK ext forbids extracting this key')
			}
		}
	}
	if normalized == 'Ed25519' {
		key_type := jwk.kty or { '' }
		curve := jwk.crv or { '' }
		if key_type != 'OKP' || curve != 'Ed25519' {
			return error('DataError: Invalid Ed25519 JWK')
		}
		if private_value := jwk.d {
			_ := jwk.x or { return error('DataError: Ed25519 private JWK has no x member') }
			private_material := base64url_decode(private_value)!
			validate_jwk_algorithm_metadata(jwk, normalized, private_material.len, hash_name,
				normalized_usages)!
			if normalized_usages.len == 0 {
				return error('SyntaxError: usages must not be empty')
			}
			return import_ed25519_key(.raw_seed, private_material, extractable, normalized_usages)
		}
		public_value := jwk.x or { return error('DataError: Ed25519 JWK has no x member') }
		public_material := base64url_decode(public_value)!
		validate_jwk_algorithm_metadata(jwk, normalized, public_material.len, hash_name,
			normalized_usages)!
		return import_ed25519_key(.raw_public, public_material, extractable, normalized_usages)
	}
	if normalized !in ['AES-CBC', 'AES-CTR', 'AES-GCM', 'AES-KW', 'HMAC', 'ChaCha20-Poly1305'] {
		return error('NotSupportedError: JWK import is unavailable for ${normalized}')
	}
	key_type := jwk.kty or { '' }
	if key_type != 'oct' {
		return error('DataError: Symmetric JWK must use kty oct')
	}
	encoded_key := jwk.k or { return error('DataError: Symmetric JWK has no k member') }
	material := base64url_decode(encoded_key)!
	validate_jwk_algorithm_metadata(jwk, normalized, material.len, hash_name, normalized_usages)!
	if normalized_usages.len == 0 {
		return error('SyntaxError: usages must not be empty')
	}
	return import_secret_key(normalized, material, extractable, normalized_usages, hash_name)
}

pub fn (subtle_crypto &SubtleCrypto) export_key(format KeyFormat, key &CryptoKey) ![]u8 {
	_ = subtle_crypto
	normalize_an_algorithm(key.algorithm_name(), 'exportKey')!
	if format !in [.raw, .raw_public, .raw_private, .raw_seed, .raw_secret] {
		return error('NotSupportedError: This typed boundary exports raw key material')
	}
	if format == .raw_seed && key.algorithm_name() == 'Ed25519' && key.type_ == .private_key {
		if !key.extractable {
			return error('InvalidAccessError: Key is not extractable')
		}
		return key.handle_[..32].clone()
	}
	return export_raw_key(key)
}

pub fn (subtle_crypto &SubtleCrypto) export_jwk(key &CryptoKey) !JsonWebKey {
	_ = subtle_crypto
	normalize_an_algorithm(key.algorithm_name(), 'exportKey')!
	if !key.extractable {
		return error('InvalidAccessError: Key is not extractable')
	}
	operations := key.usages.map(key_usage_string(it))
	if key.algorithm_name() == 'Ed25519' {
		if key.type_ == .public_key {
			return JsonWebKey{
				kty:     'OKP'
				crv:     'Ed25519'
				alg:     'Ed25519'
				x:       base64url_encode(key.handle_)
				key_ops: operations
				ext:     true
			}
		}
		if key.handle_.len != 64 {
			return error('OperationError: Invalid Ed25519 private-key handle')
		}
		return JsonWebKey{
			kty:     'OKP'
			crv:     'Ed25519'
			alg:     'Ed25519'
			x:       base64url_encode(key.handle_[32..])
			d:       base64url_encode(key.handle_[..32])
			key_ops: operations
			ext:     key.extractable
		}
	}
	if key.type_ != .secret {
		return error('NotSupportedError: JWK export backend is unavailable for ${key.algorithm_name()}')
	}
	algorithm := if key.algorithm is HmacKeyAlgorithm {
		hmac_algorithm := key.algorithm as HmacKeyAlgorithm
		expected_jwk_algorithm(key.algorithm_name(), key.handle_.len * 8, hmac_algorithm.hash)!
	} else {
		expected_jwk_algorithm(key.algorithm_name(), key.handle_.len * 8, '')!
	}
	return JsonWebKey{
		kty:     'oct'
		alg:     algorithm
		k:       base64url_encode(key.handle_)
		key_ops: operations
		ext:     key.extractable
	}
}

pub fn (subtle_crypto &SubtleCrypto) derive_bits(params DeriveParams, base_key &CryptoKey, length_bits u32) ![]u8 {
	_ = subtle_crypto
	name := match params {
		HkdfParams { params.name }
		Pbkdf2Params { params.name }
		Argon2Params { params.name }
	}
	normalize_an_algorithm(name, 'deriveBits')!
	return derive_bits_bytes(params, base_key, length_bits)
}

pub fn (subtle_crypto &SubtleCrypto) derive_key(params DeriveParams, base_key &CryptoKey, derived_algorithm string, derived_length u16, extractable bool, usages []KeyUsage) !&CryptoKey {
	if usages.len == 0 {
		return error('SyntaxError: usages must not be empty')
	}
	name := match params {
		HkdfParams { params.name }
		Pbkdf2Params { params.name }
		Argon2Params { params.name }
	}
	normalized := normalize_an_algorithm(name, 'deriveBits')!
	if normalized != base_key.algorithm_name() || !base_key.permits(.derive_key) {
		return error('InvalidAccessError: Key does not support deriving keys')
	}
	normalized_derived_algorithm := normalize_an_algorithm(derived_algorithm, 'get key length')!
	if normalized_derived_algorithm.starts_with('AES-') && derived_length !in [u16(128), 192, 256] {
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

pub fn (subtle_crypto &SubtleCrypto) wrap_key(format KeyFormat, key &CryptoKey, wrapping_key &CryptoKey, algorithm string) ![]u8 {
	normalized := normalize_an_algorithm(algorithm, 'wrapKey')!
	validate_operation_key(wrapping_key, normalized, .wrap_key)!
	plain_key := subtle_crypto.export_key_bytes_for_wrapping(format, key)!
	return aes_key_wrap(wrapping_key, plain_key)
}

pub fn (subtle_crypto &SubtleCrypto) unwrap_key(format KeyFormat, wrapped_key []u8, unwrapping_key &CryptoKey, algorithm string, unwrapped_algorithm string, extractable bool, usages []KeyUsage, hash_name string) !&CryptoKey {
	normalized := normalize_an_algorithm(algorithm, 'unwrapKey')!
	normalize_an_algorithm(unwrapped_algorithm, 'importKey')!
	validate_operation_key(unwrapping_key, normalized, .unwrap_key)!
	plain_key := aes_key_unwrap(unwrapping_key, wrapped_key)!
	return subtle_crypto.import_unwrapped_key(format, plain_key, unwrapped_algorithm, extractable, normalize_key_usages_for_operation(usages), hash_name)
}

pub fn (subtle_crypto &SubtleCrypto) encapsulate_bits(algorithm string, key &CryptoKey) !EncapsulatedBits {
	_ = subtle_crypto
	normalized := normalize_an_algorithm(algorithm, 'encapsulate')!
	validate_operation_key(key, normalized, .encapsulate_bits)!
	return error('NotSupportedError: ${normalized} encapsulation backend is unavailable')
}

pub fn (subtle_crypto &SubtleCrypto) decapsulate_bits(algorithm string, key &CryptoKey, ciphertext []u8) ![]u8 {
	_ = subtle_crypto
	_ = ciphertext
	normalized := normalize_an_algorithm(algorithm, 'decapsulate')!
	validate_operation_key(key, normalized, .decapsulate_bits)!
	return error('NotSupportedError: ${normalized} decapsulation backend is unavailable')
}

pub fn (subtle_crypto &SubtleCrypto) encapsulate_key(algorithm string, key &CryptoKey,
	shared_key_algorithm string, extractable bool, usages []KeyUsage) !EncapsulatedKey {
	bits := subtle_crypto.encapsulate_bits(algorithm, key)!
	shared_key_bits := bits.shared_key or {
		return error('OperationError: Encapsulation produced no shared key')
	}
	shared_key := subtle_crypto.import_key(.raw_secret, shared_key_bits,
		shared_key_algorithm, extractable, normalize_key_usages_for_operation(usages), '')!
	return EncapsulatedKey{
		shared_key: shared_key
		ciphertext: bits.ciphertext
	}
}

pub fn (subtle_crypto &SubtleCrypto) decapsulate_key(algorithm string, key &CryptoKey,
	ciphertext []u8, shared_key_algorithm string, extractable bool,
	usages []KeyUsage) !&CryptoKey {
	bits := subtle_crypto.decapsulate_bits(algorithm, key, ciphertext)!
	return subtle_crypto.import_key(.raw_secret, bits, shared_key_algorithm, extractable,
		normalize_key_usages_for_operation(usages), '')
}
