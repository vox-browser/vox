// SPDX-License-Identifier: BSD-2-Clause
// CryptoAlgorithms.cpp AesCbc::{encrypt,decrypt} operation bodies.
module webcrypto

fn aes_cbc_encrypt(params AesCbcParams, key &CryptoKey, plaintext []u8) ![]u8 {
	if params.iv.len != 16 {
		return error('OperationError: IV to AES-CBC must be exactly 16 bytes')
	}
	return native_aes_cbc(false, false, key.handle_, plaintext, params.iv)
}

fn aes_cbc_decrypt(params AesCbcParams, key &CryptoKey, ciphertext []u8) ![]u8 {
	if params.iv.len != 16 {
		return error('OperationError: IV to AES-CBC must be exactly 16 bytes')
	}
	if ciphertext.len == 0 || ciphertext.len % 16 != 0 {
		return error('OperationError: Ciphertext length must be a multiple of 16 bytes')
	}
	return native_aes_cbc(true, false, key.handle_, ciphertext, params.iv)
}
