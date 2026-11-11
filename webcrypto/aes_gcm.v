// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

// Crypto/CryptoAlgorithms.cpp AesGcm operations use LibCrypto's native EVP cipher.
fn aes_gcm_tag_length(params AesGcmParams) !int {
	tag_length := params.tag_length or { u8(128) }
	if tag_length !in [u8(32), 64, 96, 104, 112, 120, 128] {
		return error('OperationError: Invalid tag length')
	}
	return int(tag_length / 8)
}

fn aes_gcm_encrypt(params AesGcmParams, key &CryptoKey, plaintext []u8) ![]u8 {
	tag_size := aes_gcm_tag_length(params)!
	if u64(plaintext.len) > (u64(1) << 39) - 256 {
		return error('OperationError: Invalid plaintext length')
	}
	aad := params.additional_data or { []u8{} }
	return native_aes_gcm(false, key.handle_, plaintext, params.iv, aad, [], tag_size)
}

fn aes_gcm_decrypt(params AesGcmParams, key &CryptoKey, ciphertext []u8) ![]u8 {
	tag_size := aes_gcm_tag_length(params)!
	if ciphertext.len < tag_size {
		return error('OperationError: Invalid ciphertext length')
	}
	tag := ciphertext[ciphertext.len - tag_size..]
	actual_ciphertext := ciphertext[..ciphertext.len - tag_size]
	aad := params.additional_data or { []u8{} }
	return native_aes_gcm(true, key.handle_, actual_ciphertext, params.iv, aad, tag, tag_size)
}
