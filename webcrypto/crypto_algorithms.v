// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Crypto/CryptoAlgorithms.{h,cpp}. This file contains the
// algorithm operation bodies; native backend adapters follow upstream LibCrypto.
// Registry and WebCrypto access checks live in subtle_crypto.v.
module webcrypto

import crypto.rand
import crypto.sha1
import crypto.sha256
import crypto.sha3
import crypto.sha512
import crypto.subtle

pub struct AlgorithmParams {
pub:
	name string
}

pub struct AesCbcParams {
pub:
	name string = 'AES-CBC'
	iv   []u8
}

pub struct AesCtrParams {
pub:
	name    string = 'AES-CTR'
	counter []u8
	length  u8
}

pub struct AesGcmParams {
pub:
	name            string = 'AES-GCM'
	iv              []u8
	additional_data ?[]u8
	tag_length      ?u8
}

pub struct HkdfParams {
pub:
	name string = 'HKDF'
	hash string
	salt []u8
	info []u8
}

pub type HKDFParams = HkdfParams

pub struct Pbkdf2Params {
pub:
	name       string = 'PBKDF2'
	hash       string
	salt       []u8
	iterations u32
}

pub type PBKDF2Params = Pbkdf2Params

pub struct AesKeyGenParams {
pub:
	name   string
	length u16
}

pub struct HmacKeyGenParams {
pub:
	name   string = 'HMAC'
	hash   string
	length ?u32
}

pub struct RsaKeyGenParams {
pub:
	name            string
	modulus_length  u32
	public_exponent []u8
}

pub struct RsaHashedKeyGenParams {
pub:
	name            string
	modulus_length  u32
	public_exponent []u8
	hash            string
}

pub struct RsaHashedImportParams {
pub:
	name string
	hash string
}

pub struct RsaOaepParams {
pub:
	name  string = 'RSA-OAEP'
	label []u8
}

pub struct RsaPssParams {
pub:
	name        string = 'RSA-PSS'
	salt_length u32
}

pub struct EcdsaParams {
pub:
	name string = 'ECDSA'
	hash string
}

pub struct EcKeyGenParams {
pub:
	name        string
	named_curve string
}

pub struct AesDerivedKeyParams {
pub:
	name   string
	length u16
}

pub struct HmacImportParams {
pub:
	name   string = 'HMAC'
	hash   string
	length ?u32
}

pub struct EcdhKeyDeriveParams {
pub:
	name       string
	public_key &CryptoKey
}

pub struct EcKeyImportParams {
pub:
	name        string
	named_curve string
}

pub struct Ed448Params {
pub:
	name    string = 'Ed448'
	context ?[]u8
}

pub type ContextParams = Ed448Params

pub struct CShakeParams {
pub:
	name          string
	output_length u32
	function_name ?[]u8
	customization ?[]u8
}

pub struct KmacParams {
pub:
	name          string
	output_length u32
	customization ?[]u8
}

pub struct KmacKeyGenParams {
pub:
	name   string
	length ?u32
}

pub struct KmacImportParams {
pub:
	name   string
	length ?u32
}

pub struct AeadParams {
pub:
	name            string
	iv              []u8
	additional_data ?[]u8
	tag_length      ?u8
}

pub struct Argon2Params {
pub:
	name            string
	nonce           []u8
	parallelism     u32
	memory          u32
	passes          u32
	version         ?u8
	secret_value    ?[]u8
	associated_data ?[]u8
}

pub struct EncapsulatedBits {
pub:
	shared_key ?[]u8
	ciphertext ?[]u8
}

pub struct EncapsulatedKey {
pub:
	shared_key ?&CryptoKey
	ciphertext ?[]u8
}

pub type EncryptionParams = AeadParams
	| AesCbcParams
	| AesCtrParams
	| AesGcmParams
	| AlgorithmParams
	| RsaOaepParams

pub type DeriveParams = Argon2Params | EcdhKeyDeriveParams | HkdfParams | Pbkdf2Params

fn canonical_hash_name(name string) !string {
	return match name.to_upper() {
		'SHA-1' { 'SHA-1' }
		'SHA-256' { 'SHA-256' }
		'SHA-384' { 'SHA-384' }
		'SHA-512' { 'SHA-512' }
		'SHA3-256' { 'SHA3-256' }
		'SHA3-384' { 'SHA3-384' }
		'SHA3-512' { 'SHA3-512' }
		else { error('NotSupportedError: Unsupported hash algorithm: ${name}') }
	}
}

pub fn digest_bytes(algorithm string, data []u8) ![]u8 {
	return match canonical_hash_name(algorithm)! {
		'SHA-1' { sha1.sum(data) }
		'SHA-256' { sha256.sum256(data) }
		'SHA-384' { sha512.sum384(data) }
		'SHA-512' { sha512.sum512(data) }
		'SHA3-256' { sha3.sum256(data) }
		'SHA3-384' { sha3.sum384(data) }
		'SHA3-512' { sha3.sum512(data) }
		else {
			return error('NotSupportedError: Unsupported digest')
		}
	}
}

fn hash_block_size(name string) !int {
    return match name {
        'SHA-1', 'SHA-256' { 64 }
        'SHA-384', 'SHA-512' { 128 }
        else { return error("NotSupportedError: Invalid hash function '${name}'") }
    }
}

fn hmac_bytes(hash_name string, key []u8, data []u8) ![]u8 {
    if hash_name !in ['SHA-1', 'SHA-256', 'SHA-384', 'SHA-512'] {
        return error("NotSupportedError: Invalid hash function '${hash_name}'")
    }
    return native_hmac(hash_name, key, data)
}

pub fn hmac_sign(key &CryptoKey, data []u8) ![]u8 {
	if key.algorithm !is HmacKeyAlgorithm {
		return error('InvalidAccessError: Key is not an HMAC key')
	}
	algorithm := key.algorithm as HmacKeyAlgorithm
	return hmac_bytes(algorithm.hash, key.handle_, data)
}

pub fn hmac_verify(key &CryptoKey, signature []u8, data []u8) !bool {
	expected := hmac_sign(key, data)!
	return subtle.constant_time_compare(expected, signature) == 1
}

fn valid_aes_key(key &CryptoKey, expected_name string) ![]u8 {
	if key.type_ != .secret || key.algorithm_name() != expected_name {
		return error('InvalidAccessError: Key algorithm mismatch')
	}
	handle := key.handle_
	if handle.len !in [16, 24, 32] {
		return error('DataError: AES key length must be 128, 192, or 256 bits')
	}
	return handle
}

pub fn encrypt_bytes(params EncryptionParams, key &CryptoKey, plaintext []u8) ![]u8 {
	return match params {
		RsaOaepParams { rsa_oaep_encrypt(params, key, plaintext)! }
		AeadParams {
			if key.algorithm_name() == 'AES-OCB' { aes_ocb_crypt(params, key, plaintext, false)! }
			else { chacha20_poly1305_crypt(params, key, plaintext, false)! }
		}
		AesCbcParams { aes_cbc_encrypt(params, key, plaintext)! }
		AesCtrParams { aes_ctr_crypt(params, key, plaintext, false)! }
		AesGcmParams { aes_gcm_encrypt(params, key, plaintext)! }
		AlgorithmParams {
			if key.algorithm_name() == 'RSA-OAEP' { rsa_oaep_encrypt(RsaOaepParams{}, key, plaintext)! }
			else { error('NotSupportedError: ${params.name} encryption is unavailable') }
		}
	}
}

pub fn decrypt_bytes(params EncryptionParams, key &CryptoKey, ciphertext []u8) ![]u8 {
	return match params {
		RsaOaepParams { rsa_oaep_decrypt(params, key, ciphertext)! }
		AeadParams {
			if key.algorithm_name() == 'AES-OCB' { aes_ocb_crypt(params, key, ciphertext, true)! }
			else { chacha20_poly1305_crypt(params, key, ciphertext, true)! }
		}
		AesCbcParams { aes_cbc_decrypt(params, key, ciphertext)! }
		AesCtrParams { aes_ctr_crypt(params, key, ciphertext, true)! }
		AesGcmParams { aes_gcm_decrypt(params, key, ciphertext)! }
		AlgorithmParams {
			if key.algorithm_name() == 'RSA-OAEP' { rsa_oaep_decrypt(RsaOaepParams{}, key, ciphertext)! }
			else { error('NotSupportedError: ${params.name} decryption is unavailable') }
		}
	}
}

fn derive_bits_bytes_for_usage(params DeriveParams, base_key &CryptoKey, length_bits u32, required_usage KeyUsage) ![]u8 {
	if !base_key.permits(required_usage) {
		return error('InvalidAccessError: Key does not permit derivation')
	}
	if params is EcdhKeyDeriveParams {
		normalized := normalize_an_algorithm(params.name, 'deriveBits')!
		if normalized != base_key.algorithm_name() { return error('InvalidAccessError: Key algorithm mismatch') }
		if normalized in ['X25519', 'X448'] { return derive_exchange_bits(normalized, EcdhKeyDeriveParams{ ...params, name: normalized }, base_key, length_bits) }
		if normalized == 'ECDH' { return ecdh_derive_bits(EcdhKeyDeriveParams{ ...params, name: normalized }, base_key, length_bits) }
		return error('NotSupportedError: Derivation backend is unavailable for ${normalized}')
	}
	if params is HkdfParams {
		if normalize_an_algorithm(params.name, 'deriveBits')! != base_key.algorithm_name() { return error('InvalidAccessError: Key algorithm mismatch') }
		return hkdf_derive_bits(HkdfParams{ ...params, hash: normalize_an_algorithm(params.hash, 'digest')! }, base_key, length_bits)
	}
	if params is Argon2Params {
		normalized := normalize_an_algorithm(params.name, 'deriveBits')!
		if normalized != base_key.algorithm_name() { return error('InvalidAccessError: Key algorithm mismatch') }
		return argon2_derive_bits(Argon2Params{ ...params, name: normalized }, base_key, length_bits)
	}
	if params is Pbkdf2Params {
		if normalize_an_algorithm(params.name, 'deriveBits')! != base_key.algorithm_name() { return error('InvalidAccessError: Key algorithm mismatch') }
		return pbkdf2_derive_bits(Pbkdf2Params{ ...params, hash: normalize_an_algorithm(params.hash, 'digest')! }, base_key, length_bits)
	}
	if length_bits == 0 || length_bits % 8 != 0 {
		return error('OperationError: Derived bit length must be a positive multiple of 8')
	}
	if params.name != base_key.algorithm_name() {
		return error('InvalidAccessError: Key algorithm mismatch')
	}
	return match params {
		HkdfParams { hkdf_derive_bits(params, base_key, length_bits)! }
		Pbkdf2Params { pbkdf2_derive_bits(params, base_key, length_bits)! }
		Argon2Params { argon2_derive_bits(params, base_key, length_bits)! }
		EcdhKeyDeriveParams { error('NotSupportedError: Unexpected derivation parameters') }
	}
}

pub fn derive_bits_bytes(params DeriveParams, base_key &CryptoKey, length_bits u32) ![]u8 {
	return derive_bits_bytes_for_usage(params, base_key, length_bits, .derive_bits)
}

pub fn generate_aes_key(params AesKeyGenParams, extractable bool, usages []KeyUsage) !&CryptoKey {
    if params.name in ['AES-CBC', 'AES-CTR', 'AES-GCM', 'AES-KW'] { return generate_source_aes_key(params, extractable, usages) }
	if params.length !in [u16(128), 192, 256] {
		return error('OperationError: AES key length must be 128, 192, or 256')
	}
	allowed := match params.name {
		'AES-CBC', 'AES-CTR', 'AES-GCM', 'AES-OCB' { [KeyUsage.encrypt, .decrypt, .wrap_key, .unwrap_key] }
		'AES-KW' { [KeyUsage.wrap_key, .unwrap_key] }
		else {
			return error('NotSupportedError: Unsupported AES algorithm: ${params.name}')
		}
	}
	validate_usages(usages, allowed)!
	material := rand.bytes(int(params.length / 8))!
	return CryptoKey.create(.secret, extractable, AesKeyAlgorithm{
		name: params.name
		length: params.length
	}, usages, material)
}

pub fn import_secret_key(algorithm string, material []u8, extractable bool, usages []KeyUsage, hash_name string) !&CryptoKey {
	canonical := canonical_algorithm_name(algorithm)!
	match canonical {
        'AES-CBC', 'AES-CTR', 'AES-GCM', 'AES-KW' {
            mut key := import_aes_key(canonical, .raw, material, extractable, usages)!
            key.set_extractable(extractable)
            key.set_usages(usages)
            return key
        }
        'HMAC' {
            hash := normalize_an_algorithm(hash_name, 'digest')!
            mut key := import_hmac_key(HmacImportParams{ hash: hash }, .raw, material, extractable, usages)!
            key.set_extractable(extractable)
            key.set_usages(usages)
            return key
        }
        'ChaCha20-Poly1305' {
            mut key := import_chacha_key(.raw_secret, material, extractable, usages)!
            key.set_extractable(extractable)
            key.set_usages(usages)
            return key
        }
		'HKDF', 'PBKDF2', 'Argon2d', 'Argon2i', 'Argon2id' {
			if extractable {
				return error('SyntaxError: Derivation keys must not be extractable')
			}
			validate_usages(usages, [KeyUsage.derive_bits, .derive_key])!
			return CryptoKey.create(.secret, false, KeyAlgorithm{ name: canonical }, usages, material)
		}
		else {
			return error('NotSupportedError: Raw secret import is unavailable for ${canonical}')
		}
	}
}

pub fn export_raw_key(key &CryptoKey) ![]u8 {
	if !key.extractable {
		return error('InvalidAccessError: Key is not extractable')
	}
	return key.handle()
}

fn validate_usages(usages []KeyUsage, allowed []KeyUsage) ! {
	for usage in usages {
		if usage !in allowed {
			return error('SyntaxError: Invalid key usage ${key_usage_string(usage)}')
		}
	}
}
