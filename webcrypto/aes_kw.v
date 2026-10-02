// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

// Crypto/CryptoAlgorithms.cpp AesKw uses LibCrypto's default-IV native wrap.
pub fn aes_key_wrap(key &CryptoKey, plaintext []u8) ![]u8 {
	if plaintext.len % 8 != 0 {
		return error('OperationError: Invalid plaintext length')
	}
	return native_aes_kw(false, key.handle_, plaintext)
}

pub fn aes_key_unwrap(key &CryptoKey, ciphertext []u8) ![]u8 {
	if ciphertext.len < 8 {
		return error('OperationError: Invalid ciphertext length')
	}
	return native_aes_kw(true, key.handle_, ciphertext)
}
