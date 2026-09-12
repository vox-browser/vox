// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Crypto/CryptoAlgorithms.{h,cpp}. This file contains the
// algorithms whose backends are available in the pure-V runtime; registry and
// WebCrypto access checks live in subtle_crypto.v.
module webcrypto

import crypto.aes
import crypto.argon2
import crypto.cipher
import crypto.ed25519
import crypto.hmac
import crypto.rand
import crypto.sha1
import crypto.sha256
import crypto.sha3
import crypto.sha512
import crypto.subtle
import x.crypto.chacha20poly1305

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
	length        u32
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

pub type DeriveParams = Argon2Params | HkdfParams | Pbkdf2Params

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
	return match canonical_hash_name(name)! {
		'SHA-1', 'SHA-256' { 64 }
		'SHA-384', 'SHA-512' { 128 }
		'SHA3-256' { 136 }
		'SHA3-384' { 104 }
		'SHA3-512' { 72 }
		else {
			return error('NotSupportedError: Unsupported hash')
		}
	}
}

fn hmac_bytes(hash_name string, key []u8, data []u8) ![]u8 {
	canonical := canonical_hash_name(hash_name)!
	return match canonical {
		'SHA-1' { hmac.new(key, data, sha1.sum, 64) }
		'SHA-256' { hmac.new(key, data, sha256.sum256, 64) }
		'SHA-384' { hmac.new(key, data, sha512.sum384, 128) }
		'SHA-512' { hmac.new(key, data, sha512.sum512, 128) }
		'SHA3-256' { hmac.new(key, data, sha3.sum256, 136) }
		'SHA3-384' { hmac.new(key, data, sha3.sum384, 104) }
		'SHA3-512' { hmac.new(key, data, sha3.sum512, 72) }
		else {
			return error('NotSupportedError: Unsupported HMAC hash')
		}
	}
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

fn pkcs7_pad(data []u8) []u8 {
	padding_length := 16 - data.len % 16
	mut output := data.clone()
	output << []u8{len: padding_length, init: u8(padding_length)}
	return output
}

fn pkcs7_unpad(data []u8) ![]u8 {
	if data.len == 0 || data.len % 16 != 0 {
		return error('OperationError: Invalid AES-CBC ciphertext length')
	}
	padding_length := int(data[data.len - 1])
	if padding_length == 0 || padding_length > 16 || padding_length > data.len {
		return error('OperationError: Invalid AES-CBC padding')
	}
	for byte in data[data.len - padding_length..] {
		if byte != u8(padding_length) {
			return error('OperationError: Invalid AES-CBC padding')
		}
	}
	return data[..data.len - padding_length].clone()
}

fn aes_cbc_encrypt(params AesCbcParams, key &CryptoKey, plaintext []u8) ![]u8 {
	key_bytes := valid_aes_key(key, 'AES-CBC')!
	if params.iv.len != 16 {
		return error('OperationError: AES-CBC IV must be 16 bytes')
	}
	padded := pkcs7_pad(plaintext)
	mut output := []u8{len: padded.len}
	block := aes.new_cipher(key_bytes)!
	mut mode := cipher.new_cbc(block, params.iv)
	mode.encrypt_blocks(mut output, padded)
	return output
}

fn aes_cbc_decrypt(params AesCbcParams, key &CryptoKey, ciphertext []u8) ![]u8 {
	key_bytes := valid_aes_key(key, 'AES-CBC')!
	if params.iv.len != 16 {
		return error('OperationError: AES-CBC IV must be 16 bytes')
	}
	if ciphertext.len == 0 || ciphertext.len % 16 != 0 {
		return error('OperationError: AES-CBC ciphertext must contain full blocks')
	}
	mut output := []u8{len: ciphertext.len}
	block := aes.new_cipher(key_bytes)!
	mut mode := cipher.new_cbc(block, params.iv)
	mode.decrypt_blocks(mut output, ciphertext)
	return pkcs7_unpad(output)
}

fn increment_counter(mut counter []u8, length u8) {
	mut remaining := int(length)
	mut index := counter.len - 1
	mut carry := u16(1)
	for remaining > 0 && carry != 0 {
		bits := if remaining >= 8 { 8 } else { remaining }
		mask := u16((u16(1) << bits) - 1)
		current := u16(counter[index])
		low := (current & mask) + carry
		counter[index] = u8((current & ~mask) | (low & mask))
		carry = if low > mask { u16(1) } else { u16(0) }
		remaining -= bits
		index--
	}
}

fn aes_ctr_crypt(params AesCtrParams, key &CryptoKey, input []u8) ![]u8 {
	key_bytes := valid_aes_key(key, 'AES-CTR')!
	if params.counter.len != 16 || params.length == 0 || params.length > 128 {
		return error('OperationError: Invalid AES-CTR counter or length')
	}
	block_count := (u64(input.len) + 15) / 16
	if params.length < 64 && block_count > u64(1) << params.length {
		return error('OperationError: AES-CTR counter would repeat')
	}
	block := aes.new_cipher(key_bytes)!
	mut counter := params.counter.clone()
	mut output := []u8{len: input.len}
	mut offset := 0
	for offset < input.len {
		mut stream_block := []u8{len: 16}
		block.encrypt(mut stream_block, counter)
		count := if input.len - offset < 16 { input.len - offset } else { 16 }
		for index in 0 .. count {
			output[offset + index] = input[offset + index] ^ stream_block[index]
		}
		increment_counter(mut counter, params.length)
		offset += count
	}
	return output
}

fn gcm_shift_right(mut block []u8) {
	mut carry := u8(0)
	for index in 0 .. block.len {
		next_carry := block[index] & 1
		block[index] = (block[index] >> 1) | (carry << 7)
		carry = next_carry
	}
}

fn gcm_multiply(x []u8, y []u8) []u8 {
	mut z := []u8{len: 16}
	mut v := y.clone()
	for bit_index in 0 .. 128 {
		if x[bit_index / 8] & (u8(1) << (7 - bit_index % 8)) != 0 {
			xor_into(mut z, v)
		}
		least_significant_bit := v[15] & 1
		gcm_shift_right(mut v)
		if least_significant_bit != 0 {
			v[0] ^= 0xe1
		}
	}
	return z
}

fn append_gcm_padded(mut output []u8, input []u8) {
	output << input
	if input.len % 16 != 0 {
		output << []u8{len: 16 - input.len % 16}
	}
}

fn append_u64_be(mut output []u8, value u64) {
	for index := 7; index >= 0; index-- {
		output << u8(value >> (index * 8))
	}
}

fn gcm_hash(hash_subkey []u8, input []u8) []u8 {
	mut result := []u8{len: 16}
	for offset := 0; offset < input.len; offset += 16 {
		xor_into(mut result, input[offset..offset + 16])
		result = gcm_multiply(result, hash_subkey)
	}
	return result
}

fn gcm_increment_counter(mut counter []u8) {
	for index := 15; index >= 12; index-- {
		counter[index]++
		if counter[index] != 0 {
			break
		}
	}
}

fn gcm_counter_crypt(block cipher.Block, initial_counter []u8, input []u8) []u8 {
	mut counter := initial_counter.clone()
	mut output := []u8{len: input.len}
	for offset := 0; offset < input.len; offset += 16 {
		mut stream_block := []u8{len: 16}
		block.encrypt(mut stream_block, counter)
		count := if input.len - offset < 16 { input.len - offset } else { 16 }
		for index in 0 .. count {
			output[offset + index] = input[offset + index] ^ stream_block[index]
		}
		gcm_increment_counter(mut counter)
	}
	return output
}

fn gcm_initial_counter(iv []u8, hash_subkey []u8) []u8 {
	if iv.len == 12 {
		mut counter := iv.clone()
		counter << [u8(0), 0, 0, 1]
		return counter
	}
	mut input := []u8{}
	append_gcm_padded(mut input, iv)
	input << []u8{len: 8}
	append_u64_be(mut input, u64(iv.len) * 8)
	return gcm_hash(hash_subkey, input)
}

fn valid_gcm_tag_length(length u8) bool {
	return length in [u8(32), 64, 96, 104, 112, 120, 128]
}

fn gcm_authentication_tag(block cipher.Block, hash_subkey []u8, initial_counter []u8, additional_data []u8, ciphertext []u8) []u8 {
	mut input := []u8{}
	append_gcm_padded(mut input, additional_data)
	append_gcm_padded(mut input, ciphertext)
	append_u64_be(mut input, u64(additional_data.len) * 8)
	append_u64_be(mut input, u64(ciphertext.len) * 8)
	hashed := gcm_hash(hash_subkey, input)
	return gcm_counter_crypt(block, initial_counter, hashed)
}

fn aes_gcm_encrypt(params AesGcmParams, key &CryptoKey, plaintext []u8) ![]u8 {
	key_bytes := valid_aes_key(key, 'AES-GCM')!
	tag_length := params.tag_length or { u8(128) }
	if params.iv.len == 0 || !valid_gcm_tag_length(tag_length) {
		return error('OperationError: Invalid AES-GCM IV or tag length')
	}
	additional_data := params.additional_data or { []u8{} }
	block := aes.new_cipher(key_bytes)!
	mut hash_subkey := []u8{len: 16}
	block.encrypt(mut hash_subkey, []u8{len: 16})
	initial_counter := gcm_initial_counter(params.iv, hash_subkey)
	mut payload_counter := initial_counter.clone()
	gcm_increment_counter(mut payload_counter)
	ciphertext := gcm_counter_crypt(block, payload_counter, plaintext)
	tag := gcm_authentication_tag(block, hash_subkey, initial_counter, additional_data, ciphertext)
	mut output := ciphertext.clone()
	output << tag[..int(tag_length / 8)]
	return output
}

fn aes_gcm_decrypt(params AesGcmParams, key &CryptoKey, input []u8) ![]u8 {
	key_bytes := valid_aes_key(key, 'AES-GCM')!
	tag_length := params.tag_length or { u8(128) }
	if params.iv.len == 0 || !valid_gcm_tag_length(tag_length) {
		return error('OperationError: Invalid AES-GCM IV or tag length')
	}
	additional_data := params.additional_data or { []u8{} }
	tag_size := int(tag_length / 8)
	if input.len < tag_size {
		return error('OperationError: AES-GCM ciphertext is shorter than its tag')
	}
	ciphertext := input[..input.len - tag_size]
	tag := input[input.len - tag_size..]
	block := aes.new_cipher(key_bytes)!
	mut hash_subkey := []u8{len: 16}
	block.encrypt(mut hash_subkey, []u8{len: 16})
	initial_counter := gcm_initial_counter(params.iv, hash_subkey)
	expected := gcm_authentication_tag(block, hash_subkey, initial_counter, additional_data, ciphertext)
	if subtle.constant_time_compare(expected[..tag_size], tag) != 1 {
		return error('OperationError: AES-GCM authentication failed')
	}
	mut payload_counter := initial_counter.clone()
	gcm_increment_counter(mut payload_counter)
	return gcm_counter_crypt(block, payload_counter, ciphertext)
}

fn chacha20_poly1305_crypt(params AeadParams, key &CryptoKey, input []u8, decrypt bool) ![]u8 {
	if params.name != 'ChaCha20-Poly1305' || key.algorithm_name() != params.name || key.type_ != .secret || key.handle_.len != 32 {
		return error('InvalidAccessError: A ChaCha20-Poly1305 secret key is required')
	}
	if params.iv.len != 12 {
		return error('OperationError: ChaCha20-Poly1305 nonce must be 12 bytes')
	}
	tag_length := params.tag_length or { u8(128) }
	if tag_length != 128 {
		return error('OperationError: ChaCha20-Poly1305 tag length must be 128 bits')
	}
	additional_data := params.additional_data or { []u8{} }
	aead := chacha20poly1305.new(key.handle_, params.iv.len)!
	if decrypt {
		return aead.decrypt(input, params.iv, additional_data) or {
			return error('OperationError: ChaCha20-Poly1305 authentication failed')
		}
	}
	return aead.encrypt(input, params.iv, additional_data)!
}

pub fn encrypt_bytes(params EncryptionParams, key &CryptoKey, plaintext []u8) ![]u8 {
	return match params {
		AeadParams { chacha20_poly1305_crypt(params, key, plaintext, false)! }
		AesCbcParams { aes_cbc_encrypt(params, key, plaintext)! }
		AesCtrParams { aes_ctr_crypt(params, key, plaintext)! }
		AesGcmParams { aes_gcm_encrypt(params, key, plaintext)! }
		AlgorithmParams { error('NotSupportedError: ${params.name} encryption is unavailable') }
	}
}

pub fn decrypt_bytes(params EncryptionParams, key &CryptoKey, ciphertext []u8) ![]u8 {
	return match params {
		AeadParams { chacha20_poly1305_crypt(params, key, ciphertext, true)! }
		AesCbcParams { aes_cbc_decrypt(params, key, ciphertext)! }
		AesCtrParams { aes_ctr_crypt(params, key, ciphertext)! }
		AesGcmParams { aes_gcm_decrypt(params, key, ciphertext)! }
		AlgorithmParams { error('NotSupportedError: ${params.name} decryption is unavailable') }
	}
}

fn xor_into(mut target []u8, source []u8) {
	for index, byte in source {
		target[index] ^= byte
	}
}

fn pbkdf2_derive(params Pbkdf2Params, password []u8, length_bytes int) ![]u8 {
	if params.iterations == 0 {
		return error('OperationError: PBKDF2 iterations must be non-zero')
	}
	hash_length := digest_bytes(params.hash, [])!.len
	block_count := (length_bytes + hash_length - 1) / hash_length
	mut output := []u8{cap: block_count * hash_length}
	for block_index in 1 .. block_count + 1 {
		mut initial := params.salt.clone()
		initial << [u8(block_index >> 24), u8(block_index >> 16), u8(block_index >> 8),
			u8(block_index)]
		mut last := hmac_bytes(params.hash, password, initial)!
		mut accumulator := last.clone()
		for _ in 1 .. int(params.iterations) {
			last = hmac_bytes(params.hash, password, last)!
			xor_into(mut accumulator, last)
		}
		output << accumulator
	}
	return output[..length_bytes].clone()
}

fn hkdf_derive(params HkdfParams, secret []u8, length_bytes int) ![]u8 {
	hash_length := digest_bytes(params.hash, [])!.len
	if length_bytes > 255 * hash_length {
		return error('OperationError: HKDF output is too long')
	}
	salt := if params.salt.len == 0 { []u8{len: hash_length} } else { params.salt.clone() }
	prk := hmac_bytes(params.hash, salt, secret)!
	mut output := []u8{cap: length_bytes}
	mut previous := []u8{}
	mut counter := u8(0)
	for output.len < length_bytes {
		counter++
		mut input := previous.clone()
		input << params.info
		input << counter
		previous = hmac_bytes(params.hash, prk, input)!
		remaining := length_bytes - output.len
		output << previous[..if remaining < previous.len { remaining } else { previous.len }]
	}
	return output
}

fn argon2_derive(params Argon2Params, password []u8, length_bytes int) ![]u8 {
	if params.secret_value != none || params.associated_data != none {
		return error('NotSupportedError: The pure-V Argon2 backend has no secret/associated-data input')
	}
	if params.parallelism == 0 || params.parallelism > 255 || params.passes == 0 {
		return error('OperationError: Invalid Argon2 cost parameters')
	}
	return match params.name {
		'Argon2d' {
			argon2.d_key(password, params.nonce, params.passes, params.memory, u8(params.parallelism), u32(length_bytes))!
		}
		'Argon2i' {
			argon2.key(password, params.nonce, params.passes, params.memory, u8(params.parallelism), u32(length_bytes))!
		}
		'Argon2id' {
			argon2.id_key(password, params.nonce, params.passes, params.memory, u8(params.parallelism), u32(length_bytes))!
		}
		else {
			error('NotSupportedError: Unsupported Argon2 variant')
		}
	}
}

fn derive_bits_bytes_for_usage(params DeriveParams, base_key &CryptoKey, length_bits u32, required_usage KeyUsage) ![]u8 {
	if !base_key.permits(required_usage) {
		return error('InvalidAccessError: Key does not permit derivation')
	}
	if length_bits == 0 || length_bits % 8 != 0 {
		return error('OperationError: Derived bit length must be a positive multiple of 8')
	}
	if params.name != base_key.algorithm_name() {
		return error('InvalidAccessError: Key algorithm mismatch')
	}
	length_bytes := int(length_bits / 8)
	return match params {
		HkdfParams { hkdf_derive(params, base_key.handle_, length_bytes)! }
		Pbkdf2Params { pbkdf2_derive(params, base_key.handle_, length_bytes)! }
		Argon2Params { argon2_derive(params, base_key.handle_, length_bytes)! }
	}
}

pub fn derive_bits_bytes(params DeriveParams, base_key &CryptoKey, length_bits u32) ![]u8 {
	return derive_bits_bytes_for_usage(params, base_key, length_bits, .derive_bits)
}

pub fn generate_aes_key(params AesKeyGenParams, extractable bool, usages []KeyUsage) !&CryptoKey {
	if params.length !in [u16(128), 192, 256] {
		return error('OperationError: AES key length must be 128, 192, or 256')
	}
	allowed := match params.name {
		'AES-CBC', 'AES-CTR', 'AES-GCM' { [KeyUsage.encrypt, .decrypt, .wrap_key, .unwrap_key] }
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
			if material.len !in [16, 24, 32] {
				return error('DataError: Invalid AES key length')
			}
			allowed := if canonical == 'AES-KW' {
				[KeyUsage.wrap_key, .unwrap_key]
			} else {
				[KeyUsage.encrypt, .decrypt, .wrap_key, .unwrap_key]
			}
			validate_usages(usages, allowed)!
			return CryptoKey.create(.secret, extractable, AesKeyAlgorithm{
				name: canonical
				length: u16(material.len * 8)
			}, usages, material)
		}
		'HMAC' {
			if material.len == 0 {
				return error('DataError: HMAC key must not be empty')
			}
			validate_usages(usages, [KeyUsage.sign, .verify])!
			hash := canonical_hash_name(hash_name)!
			return CryptoKey.create(.secret, extractable, HmacKeyAlgorithm{
				hash: hash
				length: u32(material.len * 8)
			}, usages, material)
		}
		'ChaCha20-Poly1305' {
			if material.len != 32 {
				return error('DataError: ChaCha20-Poly1305 key must be 256 bits')
			}
			validate_usages(usages, [KeyUsage.encrypt, .decrypt, .wrap_key, .unwrap_key])!
			return CryptoKey.create(.secret, extractable, KeyAlgorithm{ name: canonical }, usages, material)
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

pub fn generate_hmac_key(params HmacKeyGenParams, extractable bool, usages []KeyUsage) !&CryptoKey {
	validate_usages(usages, [KeyUsage.sign, .verify])!
	hash := canonical_hash_name(params.hash)!
	default_length := u32(hash_block_size(hash)! * 8)
	length := params.length or { default_length }
	if length == 0 || length % 8 != 0 {
		return error('OperationError: HMAC key length must be a positive multiple of 8')
	}
	material := rand.bytes(int(length / 8))!
	return CryptoKey.create(.secret, extractable, HmacKeyAlgorithm{
		hash: hash
		length: length
	}, usages, material)
}

pub fn generate_ed25519_key(extractable bool, usages []KeyUsage) !CryptoKeyPair {
	validate_usages(usages, [KeyUsage.sign, .verify])!
	public_material, private_material := ed25519.generate_key()!
	public_usages := if KeyUsage.verify in usages { [KeyUsage.verify] } else { []KeyUsage{} }
	private_usages := if KeyUsage.sign in usages { [KeyUsage.sign] } else { []KeyUsage{} }
	return CryptoKeyPair{
		public_key: CryptoKey.create(.public_key, true, KeyAlgorithm{ name: 'Ed25519' }, public_usages, public_material)
		private_key: CryptoKey.create(.private_key, extractable, KeyAlgorithm{ name: 'Ed25519' }, private_usages, private_material)
	}
}

pub fn import_ed25519_key(format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey {
	return match format {
		.raw, .raw_public {
			if material.len != ed25519.public_key_size {
				return error('DataError: Ed25519 public key must be 32 bytes')
			}
			validate_usages(usages, [KeyUsage.verify])!
			CryptoKey.create(.public_key, extractable, KeyAlgorithm{ name: 'Ed25519' }, usages, material)
		}
		.raw_seed {
			if material.len != ed25519.seed_size {
				return error('DataError: Ed25519 seed must be 32 bytes')
			}
			validate_usages(usages, [KeyUsage.sign])!
			private_material := ed25519.new_key_from_seed(material)
			CryptoKey.create(.private_key, extractable, KeyAlgorithm{ name: 'Ed25519' }, usages, private_material)
		}
		.raw_private {
			if material.len != ed25519.private_key_size {
				return error('DataError: Ed25519 private key must be 64 bytes')
			}
			validate_usages(usages, [KeyUsage.sign])!
			CryptoKey.create(.private_key, extractable, KeyAlgorithm{ name: 'Ed25519' }, usages, material)
		}
		else {
			error('NotSupportedError: Ed25519 format is not implemented')
		}
	}
}

pub fn ed25519_public_key_from_seed(seed []u8) ![]u8 {
	if seed.len != ed25519.seed_size {
		return error('DataError: Ed25519 seed must be 32 bytes')
	}
	private_key := ed25519.new_key_from_seed(seed)
	return private_key[ed25519.seed_size..].clone()
}

pub fn import_ed448_key(format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey {
	return match format {
		.raw, .raw_public {
			// Ed448 is named for its 448-bit prime field, but RFC 8032 encodes
			// public keys using 456 bits.
			if material.len != 57 {
				return error('DataError: Ed448 public key must be 57 bytes')
			}
			validate_usages(usages, [KeyUsage.verify])!
			CryptoKey.create(.public_key, extractable, KeyAlgorithm{ name: 'Ed448' }, usages, material)
		}
		else {
			error('NotSupportedError: Ed448 format is not implemented')
		}
	}
}

pub fn ed25519_sign(key &CryptoKey, message []u8) ![]u8 {
	if key.algorithm_name() != 'Ed25519' || key.type_ != .private_key {
		return error('InvalidAccessError: An Ed25519 private key is required')
	}
	return ed25519.sign(ed25519.PrivateKey(key.handle_), message)!
}

pub fn ed25519_verify(key &CryptoKey, signature []u8, message []u8) !bool {
	if key.algorithm_name() != 'Ed25519' || key.type_ != .public_key {
		return error('InvalidAccessError: An Ed25519 public key is required')
	}
	return ed25519.verify(ed25519.PublicKey(key.handle_), message, signature)!
}

pub fn export_raw_key(key &CryptoKey) ![]u8 {
	if !key.extractable {
		return error('InvalidAccessError: Key is not extractable')
	}
	return key.handle()
}

fn xor_wrap_counter(mut block []u8, counter u64) {
	for byte_index in 0 .. 8 {
		block[7 - byte_index] ^= u8(counter >> (byte_index * 8))
	}
}

// RFC 3394 AES Key Wrap, used by the WebCrypto AES-KW algorithm.
pub fn aes_key_wrap(key &CryptoKey, plaintext []u8) ![]u8 {
	key_bytes := valid_aes_key(key, 'AES-KW')!
	if plaintext.len < 16 || plaintext.len % 8 != 0 {
		return error('OperationError: AES-KW input must be at least 16 bytes and a multiple of 8')
	}
	n := plaintext.len / 8
	mut a := []u8{len: 8, init: 0xa6}
	mut r := plaintext.clone()
	block_cipher := aes.new_cipher(key_bytes)!
	for round in 0 .. 6 {
		for index in 0 .. n {
			mut input := a.clone()
			input << r[index * 8..index * 8 + 8]
			mut output := []u8{len: 16}
			block_cipher.encrypt(mut output, input)
			a = output[..8].clone()
			xor_wrap_counter(mut a, u64(round * n + index + 1))
			copy(mut r[index * 8..index * 8 + 8], output[8..])
		}
	}
	mut wrapped := a.clone()
	wrapped << r
	return wrapped
}

pub fn aes_key_unwrap(key &CryptoKey, ciphertext []u8) ![]u8 {
	key_bytes := valid_aes_key(key, 'AES-KW')!
	if ciphertext.len < 24 || ciphertext.len % 8 != 0 {
		return error('OperationError: Invalid AES-KW ciphertext length')
	}
	n := ciphertext.len / 8 - 1
	mut a := ciphertext[..8].clone()
	mut r := ciphertext[8..].clone()
	block_cipher := aes.new_cipher(key_bytes)!
	for round := 5; round >= 0; round-- {
		for index := n - 1; index >= 0; index-- {
			mut first := a.clone()
			xor_wrap_counter(mut first, u64(round * n + index + 1))
			mut input := first.clone()
			input << r[index * 8..index * 8 + 8]
			mut output := []u8{len: 16}
			block_cipher.decrypt(mut output, input)
			a = output[..8].clone()
			copy(mut r[index * 8..index * 8 + 8], output[8..])
		}
	}
	if subtle.constant_time_compare(a, []u8{len: 8, init: 0xa6}) != 1 {
		return error('OperationError: AES-KW integrity check failed')
	}
	return r
}

fn validate_usages(usages []KeyUsage, allowed []KeyUsage) ! {
	for usage in usages {
		if usage !in allowed {
			return error('SyntaxError: Invalid key usage ${key_usage_string(usage)}')
		}
	}
}
