// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Concrete AlgorithmMethods translations. These objects preserve the C++
// dispatch surface while delegating to the same primitives used by
// SubtleCrypto.
module webcrypto

fn backend_unavailable[T](algorithm string, operation string) !T {
	return error('NotSupportedError: ${algorithm} ${operation} backend is unavailable')
}

fn import_secret_algorithm(name string, format KeyFormat, material []u8, extractable bool,
	usages []KeyUsage, hash_name string) !&CryptoKey {
	return SubtleCrypto.create().import_key(format, material, name, extractable, usages,
		hash_name)
}

fn export_algorithm_key(format KeyFormat, key &CryptoKey) ![]u8 {
	return SubtleCrypto.create().export_key(format, key)
}

fn aes_key_length(params AesKeyGenParams) !u32 {
	if params.length !in [u16(128), 192, 256] {
		return error('OperationError: AES key length must be 128, 192, or 256 bits')
	}
	return u32(params.length)
}

pub struct AesCbc {}
pub fn AesCbc.create() AesCbc { return AesCbc{} }
pub fn (_ AesCbc) encrypt(params AesCbcParams, key &CryptoKey, data []u8) ![]u8 { return aes_cbc_encrypt(params, key, data) }
pub fn (_ AesCbc) decrypt(params AesCbcParams, key &CryptoKey, data []u8) ![]u8 { return aes_cbc_decrypt(params, key, data) }
pub fn (_ AesCbc) import_key(format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey { return import_secret_algorithm('AES-CBC', format, material, extractable, usages, '') }
pub fn (_ AesCbc) generate_key(params AesKeyGenParams, extractable bool, usages []KeyUsage) !GeneratedKey { return GeneratedKey{key: generate_aes_key(AesKeyGenParams{...params, name: 'AES-CBC'}, extractable, usages)!} }
pub fn (_ AesCbc) export_key(format KeyFormat, key &CryptoKey) ![]u8 { return export_algorithm_key(format, key) }
pub fn (_ AesCbc) get_key_length(params AesKeyGenParams) !KeyLengthResult { return KeyLengthResult{value: aes_key_length(params)!} }

pub struct AesCtr {}
pub fn AesCtr.create() AesCtr { return AesCtr{} }
pub fn (_ AesCtr) encrypt(params AesCtrParams, key &CryptoKey, data []u8) ![]u8 { return aes_ctr_crypt(params, key, data) }
pub fn (_ AesCtr) decrypt(params AesCtrParams, key &CryptoKey, data []u8) ![]u8 { return aes_ctr_crypt(params, key, data) }
pub fn (_ AesCtr) import_key(format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey { return import_secret_algorithm('AES-CTR', format, material, extractable, usages, '') }
pub fn (_ AesCtr) export_key(format KeyFormat, key &CryptoKey) ![]u8 { return export_algorithm_key(format, key) }
pub fn (_ AesCtr) get_key_length(params AesKeyGenParams) !KeyLengthResult { return KeyLengthResult{value: aes_key_length(params)!} }
pub fn (_ AesCtr) generate_key(params AesKeyGenParams, extractable bool, usages []KeyUsage) !GeneratedKey { return GeneratedKey{key: generate_aes_key(AesKeyGenParams{...params, name: 'AES-CTR'}, extractable, usages)!} }

pub struct AesGcm {}
pub fn AesGcm.create() AesGcm { return AesGcm{} }
pub fn (_ AesGcm) encrypt(params AesGcmParams, key &CryptoKey, data []u8) ![]u8 { return aes_gcm_encrypt(params, key, data) }
pub fn (_ AesGcm) decrypt(params AesGcmParams, key &CryptoKey, data []u8) ![]u8 { return aes_gcm_decrypt(params, key, data) }
pub fn (_ AesGcm) get_key_length(params AesKeyGenParams) !KeyLengthResult { return KeyLengthResult{value: aes_key_length(params)!} }
pub fn (_ AesGcm) import_key(format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey { return import_secret_algorithm('AES-GCM', format, material, extractable, usages, '') }
pub fn (_ AesGcm) export_key(format KeyFormat, key &CryptoKey) ![]u8 { return export_algorithm_key(format, key) }
pub fn (_ AesGcm) generate_key(params AesKeyGenParams, extractable bool, usages []KeyUsage) !GeneratedKey { return GeneratedKey{key: generate_aes_key(AesKeyGenParams{...params, name: 'AES-GCM'}, extractable, usages)!} }

pub struct AesKw {}
pub fn AesKw.create() AesKw { return AesKw{} }
pub fn (_ AesKw) import_key(format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey { return import_secret_algorithm('AES-KW', format, material, extractable, usages, '') }
pub fn (_ AesKw) export_key(format KeyFormat, key &CryptoKey) ![]u8 { return export_algorithm_key(format, key) }
pub fn (_ AesKw) get_key_length(params AesKeyGenParams) !KeyLengthResult { return KeyLengthResult{value: aes_key_length(params)!} }
pub fn (_ AesKw) generate_key(params AesKeyGenParams, extractable bool, usages []KeyUsage) !GeneratedKey { return GeneratedKey{key: generate_aes_key(AesKeyGenParams{...params, name: 'AES-KW'}, extractable, usages)!} }
pub fn (_ AesKw) wrap_key(_ AlgorithmParams, key &CryptoKey, data []u8) ![]u8 { return aes_key_wrap(key, data) }
pub fn (_ AesKw) unwrap_key(_ AlgorithmParams, key &CryptoKey, data []u8) ![]u8 { return aes_key_unwrap(key, data) }

pub struct ChaCha20Poly1305 {}
pub fn ChaCha20Poly1305.create() ChaCha20Poly1305 { return ChaCha20Poly1305{} }
pub fn (_ ChaCha20Poly1305) encrypt(params AeadParams, key &CryptoKey, data []u8) ![]u8 { return chacha20_poly1305_crypt(params, key, data, false) }
pub fn (_ ChaCha20Poly1305) decrypt(params AeadParams, key &CryptoKey, data []u8) ![]u8 { return chacha20_poly1305_crypt(params, key, data, true) }
pub fn (_ ChaCha20Poly1305) generate_key(_ AlgorithmParams, extractable bool, usages []KeyUsage) !GeneratedKey { return SubtleCrypto.create().generate_key(AlgorithmParams{name: 'ChaCha20-Poly1305'}, extractable, usages) }
pub fn (_ ChaCha20Poly1305) import_key(format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey { return import_secret_algorithm('ChaCha20-Poly1305', format, material, extractable, usages, '') }
pub fn (_ ChaCha20Poly1305) export_key(format KeyFormat, key &CryptoKey) ![]u8 { return export_algorithm_key(format, key) }
pub fn (_ ChaCha20Poly1305) get_key_length(_ AlgorithmParams) !KeyLengthResult { return KeyLengthResult{value: u32(256)} }

pub struct SHA {}
pub fn SHA.create() SHA { return SHA{} }
pub fn (_ SHA) digest(params AlgorithmParams, data []u8) ![]u8 { return digest_bytes(params.name, data) }

pub struct HMAC {}
pub fn HMAC.create() HMAC { return HMAC{} }
pub fn (_ HMAC) sign(_ AlgorithmParams, key &CryptoKey, data []u8) ![]u8 { return hmac_sign(key, data) }
pub fn (_ HMAC) verify(_ AlgorithmParams, key &CryptoKey, signature []u8, data []u8) !bool { return hmac_verify(key, signature, data) }
pub fn (_ HMAC) generate_key(params HmacKeyGenParams, extractable bool, usages []KeyUsage) !GeneratedKey { return GeneratedKey{key: generate_hmac_key(params, extractable, usages)!} }
pub fn (_ HMAC) import_key(params HmacImportParams, format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey { return import_secret_algorithm('HMAC', format, material, extractable, usages, params.hash) }
pub fn (_ HMAC) export_key(format KeyFormat, key &CryptoKey) ![]u8 { return export_algorithm_key(format, key) }
pub fn (_ HMAC) get_key_length(params HmacImportParams) !KeyLengthResult {
	length := params.length or { u32(hash_block_size(params.hash)! * 8) }
	if length == 0 { return error('TypeError: Invalid key length') }
	return KeyLengthResult{value: length}
}

pub struct ED25519 {}
pub fn ED25519.create() ED25519 { return ED25519{} }
pub fn (_ ED25519) sign(_ AlgorithmParams, key &CryptoKey, data []u8) ![]u8 { return ed25519_sign(key, data) }
pub fn (_ ED25519) verify(_ AlgorithmParams, key &CryptoKey, signature []u8, data []u8) !bool { return ed25519_verify(key, signature, data) }
pub fn (_ ED25519) generate_key(_ AlgorithmParams, extractable bool, usages []KeyUsage) !GeneratedKey { return GeneratedKey{pair: generate_ed25519_key(extractable, usages)!} }
pub fn (_ ED25519) import_key(_ AlgorithmParams, format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey { return import_ed25519_key(format, material, extractable, usages) }
pub fn (_ ED25519) export_key(format KeyFormat, key &CryptoKey) ![]u8 { return export_algorithm_key(format, key) }

pub struct HKDF {}
pub fn HKDF.create() HKDF { return HKDF{} }
pub fn (_ HKDF) import_key(_ AlgorithmParams, format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey { return import_secret_algorithm('HKDF', format, material, extractable, usages, '') }
pub fn (_ HKDF) derive_bits(params HkdfParams, key &CryptoKey, length ?u32) ![]u8 { return derive_bits_bytes(params, key, length or { return error('OperationError: length is required') }) }
pub fn (_ HKDF) get_key_length(_ AlgorithmParams) !KeyLengthResult { return KeyLengthResult{} }

pub struct PBKDF2 {}
pub fn PBKDF2.create() PBKDF2 { return PBKDF2{} }
pub fn (_ PBKDF2) import_key(_ AlgorithmParams, format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey { return import_secret_algorithm('PBKDF2', format, material, extractable, usages, '') }
pub fn (_ PBKDF2) derive_bits(params Pbkdf2Params, key &CryptoKey, length ?u32) ![]u8 { return derive_bits_bytes(params, key, length or { return error('OperationError: length is required') }) }
pub fn (_ PBKDF2) get_key_length(_ AlgorithmParams) !KeyLengthResult { return KeyLengthResult{} }

pub struct Argon2 {}
pub fn Argon2.create() Argon2 { return Argon2{} }
pub fn (_ Argon2) import_key(params AlgorithmParams, format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey { return import_secret_algorithm(params.name, format, material, extractable, usages, '') }
pub fn (_ Argon2) derive_bits(params Argon2Params, key &CryptoKey, length ?u32) ![]u8 { return derive_bits_bytes(params, key, length or { return error('OperationError: length is required') }) }
pub fn (_ Argon2) get_key_length(_ AlgorithmParams) !KeyLengthResult { return KeyLengthResult{} }

// Algorithms whose low-level primitives are not provided by this V runtime.
// Their typed dispatch and error behavior remain concrete rather than being
// silently substituted with a different cryptosystem.

pub struct RSAOAEP {}
pub fn RSAOAEP.create() RSAOAEP { return RSAOAEP{} }
pub fn (_ RSAOAEP) encrypt(_ RsaOaepParams, _ &CryptoKey, _ []u8) ![]u8 { return backend_unavailable[[]u8]('RSA-OAEP', 'encryption') }
pub fn (_ RSAOAEP) decrypt(_ RsaOaepParams, _ &CryptoKey, _ []u8) ![]u8 { return backend_unavailable[[]u8]('RSA-OAEP', 'decryption') }
pub fn (_ RSAOAEP) generate_key(_ RsaHashedKeyGenParams, _ bool, _ []KeyUsage) !GeneratedKey { return backend_unavailable[GeneratedKey]('RSA-OAEP', 'key generation') }
pub fn (_ RSAOAEP) import_key(_ RsaHashedImportParams, _ KeyFormat, _ []u8, _ bool, _ []KeyUsage) !&CryptoKey { return backend_unavailable[&CryptoKey]('RSA-OAEP', 'key import') }
pub fn (_ RSAOAEP) export_key(_ KeyFormat, _ &CryptoKey) ![]u8 { return backend_unavailable[[]u8]('RSA-OAEP', 'key export') }

pub struct RSAPSS {}
pub fn RSAPSS.create() RSAPSS { return RSAPSS{} }
pub fn (_ RSAPSS) sign(_ RsaPssParams, _ &CryptoKey, _ []u8) ![]u8 { return backend_unavailable[[]u8]('RSA-PSS', 'signing') }
pub fn (_ RSAPSS) verify(_ RsaPssParams, _ &CryptoKey, _ []u8, _ []u8) !bool { return backend_unavailable[bool]('RSA-PSS', 'verification') }
pub fn (_ RSAPSS) generate_key(_ RsaHashedKeyGenParams, _ bool, _ []KeyUsage) !GeneratedKey { return backend_unavailable[GeneratedKey]('RSA-PSS', 'key generation') }
pub fn (_ RSAPSS) import_key(_ RsaHashedImportParams, _ KeyFormat, _ []u8, _ bool, _ []KeyUsage) !&CryptoKey { return backend_unavailable[&CryptoKey]('RSA-PSS', 'key import') }
pub fn (_ RSAPSS) export_key(_ KeyFormat, _ &CryptoKey) ![]u8 { return backend_unavailable[[]u8]('RSA-PSS', 'key export') }

pub struct RSASSAPKCS1 {}
pub fn RSASSAPKCS1.create() RSASSAPKCS1 { return RSASSAPKCS1{} }
pub fn (_ RSASSAPKCS1) sign(_ AlgorithmParams, _ &CryptoKey, _ []u8) ![]u8 { return backend_unavailable[[]u8]('RSASSA-PKCS1-v1_5', 'signing') }
pub fn (_ RSASSAPKCS1) verify(_ AlgorithmParams, _ &CryptoKey, _ []u8, _ []u8) !bool { return backend_unavailable[bool]('RSASSA-PKCS1-v1_5', 'verification') }
pub fn (_ RSASSAPKCS1) generate_key(_ RsaHashedKeyGenParams, _ bool, _ []KeyUsage) !GeneratedKey { return backend_unavailable[GeneratedKey]('RSASSA-PKCS1-v1_5', 'key generation') }
pub fn (_ RSASSAPKCS1) import_key(_ RsaHashedImportParams, _ KeyFormat, _ []u8, _ bool, _ []KeyUsage) !&CryptoKey { return backend_unavailable[&CryptoKey]('RSASSA-PKCS1-v1_5', 'key import') }
pub fn (_ RSASSAPKCS1) export_key(_ KeyFormat, _ &CryptoKey) ![]u8 { return backend_unavailable[[]u8]('RSASSA-PKCS1-v1_5', 'key export') }

pub struct ECDSA {}
pub fn ECDSA.create() ECDSA { return ECDSA{} }
pub fn (_ ECDSA) generate_key(_ EcKeyGenParams, _ bool, _ []KeyUsage) !GeneratedKey { return backend_unavailable[GeneratedKey]('ECDSA', 'key generation') }
pub fn (_ ECDSA) sign(_ EcdsaParams, _ &CryptoKey, _ []u8) ![]u8 { return backend_unavailable[[]u8]('ECDSA', 'signing') }
pub fn (_ ECDSA) verify(_ EcdsaParams, _ &CryptoKey, _ []u8, _ []u8) !bool { return backend_unavailable[bool]('ECDSA', 'verification') }
pub fn (_ ECDSA) import_key(_ EcKeyImportParams, _ KeyFormat, _ []u8, _ bool, _ []KeyUsage) !&CryptoKey { return backend_unavailable[&CryptoKey]('ECDSA', 'key import') }
pub fn (_ ECDSA) export_key(_ KeyFormat, _ &CryptoKey) ![]u8 { return backend_unavailable[[]u8]('ECDSA', 'key export') }

pub struct ECDH {}
pub fn ECDH.create() ECDH { return ECDH{} }
pub fn (_ ECDH) generate_key(_ EcKeyGenParams, _ bool, _ []KeyUsage) !GeneratedKey { return backend_unavailable[GeneratedKey]('ECDH', 'key generation') }
pub fn (_ ECDH) derive_bits(_ EcdhKeyDeriveParams, _ &CryptoKey, _ ?u32) ![]u8 { return backend_unavailable[[]u8]('ECDH', 'derivation') }
pub fn (_ ECDH) import_key(_ EcKeyImportParams, _ KeyFormat, _ []u8, _ bool, _ []KeyUsage) !&CryptoKey { return backend_unavailable[&CryptoKey]('ECDH', 'key import') }
pub fn (_ ECDH) export_key(_ KeyFormat, _ &CryptoKey) ![]u8 { return backend_unavailable[[]u8]('ECDH', 'key export') }

pub struct X25519 {}
pub fn X25519.create() X25519 { return X25519{} }
pub fn (_ X25519) derive_bits(params EcdhKeyDeriveParams, key &CryptoKey, length ?u32) ![]u8 { return derive_exchange_bits('X25519', params, key, length) }
pub fn (_ X25519) generate_key(_ AlgorithmParams, extractable bool, usages []KeyUsage) !GeneratedKey { return generate_exchange_key('X25519', extractable, usages) }
pub fn (_ X25519) import_key(_ AlgorithmParams, format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey { return import_exchange_key('X25519', format, material, extractable, usages) }
pub fn (_ X25519) export_key(format KeyFormat, key &CryptoKey) ![]u8 { return export_exchange_key('X25519', format, key) }

pub struct X448 {}
pub fn X448.create() X448 { return X448{} }
pub fn (_ X448) derive_bits(params EcdhKeyDeriveParams, key &CryptoKey, length ?u32) ![]u8 { return derive_exchange_bits('X448', params, key, length) }
pub fn (_ X448) generate_key(_ AlgorithmParams, extractable bool, usages []KeyUsage) !GeneratedKey { return generate_exchange_key('X448', extractable, usages) }
pub fn (_ X448) import_key(_ AlgorithmParams, format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey { return import_exchange_key('X448', format, material, extractable, usages) }
pub fn (_ X448) export_key(format KeyFormat, key &CryptoKey) ![]u8 { return export_exchange_key('X448', format, key) }

pub struct ED448 {}
pub fn ED448.create() ED448 { return ED448{} }
pub fn (_ ED448) generate_key(_ AlgorithmParams, extractable bool, usages []KeyUsage) !GeneratedKey { return generate_ed448_key(extractable, usages) }
pub fn (_ ED448) import_key(_ AlgorithmParams, format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey { return import_ed448_key(format, material, extractable, usages) }
pub fn (_ ED448) export_key(format KeyFormat, key &CryptoKey) ![]u8 { return export_ed448_key(format, key) }
pub fn (_ ED448) sign(params Ed448Params, key &CryptoKey, message []u8) ![]u8 { return ed448_sign(params, key, message) }
pub fn (_ ED448) verify(params Ed448Params, key &CryptoKey, signature []u8, message []u8) !bool { return ed448_verify(params, key, signature, message) }

pub struct MLDSA {}
pub fn MLDSA.create() MLDSA { return MLDSA{} }
pub fn (_ MLDSA) sign(params Ed448Params, key &CryptoKey, message []u8) ![]u8 { return mldsa_sign(params, key, message) }
pub fn (_ MLDSA) verify(params Ed448Params, key &CryptoKey, signature []u8, message []u8) !bool { return mldsa_verify(params, key, signature, message) }
pub fn (_ MLDSA) generate_key(params AlgorithmParams, extractable bool, usages []KeyUsage) !GeneratedKey { return generate_mldsa_key(params, extractable, usages) }
pub fn (_ MLDSA) import_key(params AlgorithmParams, format KeyFormat, bytes []u8, extractable bool, usages []KeyUsage) !&CryptoKey { return import_mldsa_key(params, format, bytes, extractable, usages) }
pub fn (_ MLDSA) export_key(format KeyFormat, key &CryptoKey) ![]u8 { return export_mldsa_key(format, key) }

pub struct MLKEM {}
pub fn MLKEM.create() MLKEM { return MLKEM{} }
pub fn (_ MLKEM) generate_key(params AlgorithmParams, extractable bool, usages []KeyUsage) !GeneratedKey { return generate_mlkem_key(params, extractable, usages) }
pub fn (_ MLKEM) import_key(params AlgorithmParams, format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey { return import_mlkem_key(params, format, material, extractable, usages) }
pub fn (_ MLKEM) export_key(format KeyFormat, key &CryptoKey) ![]u8 { return export_mlkem_key(format, key) }
pub fn (_ MLKEM) encapsulate(params AlgorithmParams, key &CryptoKey) !EncapsulatedBits { return mlkem_encapsulate(params, key) }
pub fn (_ MLKEM) decapsulate(params AlgorithmParams, key &CryptoKey, ciphertext []u8) ![]u8 { return mlkem_decapsulate(params, key, ciphertext) }

pub struct KMAC {}
pub fn KMAC.create() KMAC { return KMAC{} }
pub fn (_ KMAC) sign(params KmacParams, key &CryptoKey, data []u8) ![]u8 { return kmac_sign(params, key, data) }
pub fn (_ KMAC) verify(params KmacParams, key &CryptoKey, signature []u8, data []u8) !bool { return kmac_sign(params, key, data)! == signature }
pub fn (_ KMAC) generate_key(params KmacKeyGenParams, extractable bool, usages []KeyUsage) !GeneratedKey { return GeneratedKey{key: generate_kmac_key(params, extractable, usages)!} }
pub fn (_ KMAC) import_key(params KmacImportParams, format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey { return import_kmac_key(params, format, material, extractable, usages) }
pub fn (_ KMAC) export_key(format KeyFormat, key &CryptoKey) ![]u8 { return export_kmac_key(format, key) }
pub fn (_ KMAC) get_key_length(params KmacImportParams) !KeyLengthResult {
	length := params.length or {
		match params.name {
			'KMAC128' { u32(128) }
			'KMAC256' { u32(256) }
			else { return error('OperationError: Unsupported KMAC algorithm') }
		}
	}
	return KeyLengthResult{value: length}
}

pub struct CShake {}
pub fn CShake.create() CShake { return CShake{} }
pub fn (_ CShake) digest(params CShakeParams, data []u8) ![]u8 { return cshake_digest(params, data) }

pub struct AesOcb {}
pub fn AesOcb.create() AesOcb { return AesOcb{} }
pub fn (_ AesOcb) encrypt(params AeadParams, key &CryptoKey, data []u8) ![]u8 { return aes_ocb_crypt(params, key, data, false) }
pub fn (_ AesOcb) decrypt(params AeadParams, key &CryptoKey, data []u8) ![]u8 { return aes_ocb_crypt(params, key, data, true) }
pub fn (_ AesOcb) generate_key(params AesKeyGenParams, extractable bool, usages []KeyUsage) !GeneratedKey { return GeneratedKey{key: generate_aes_key(AesKeyGenParams{...params, name: 'AES-OCB'}, extractable, usages)!} }
pub fn (_ AesOcb) import_key(_ AlgorithmParams, format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey { return import_aes_ocb_key(format, material, extractable, usages) }
pub fn (_ AesOcb) export_key(format KeyFormat, key &CryptoKey) ![]u8 { return export_aes_ocb_key(format, key) }
pub fn (_ AesOcb) get_key_length(params AesKeyGenParams) !KeyLengthResult { return KeyLengthResult{value: aes_key_length(params)!} }
