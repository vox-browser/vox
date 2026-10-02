// SPDX-License-Identifier: BSD-2-Clause
// CryptoAlgorithms.cpp AesCtr::{encrypt,decrypt} operation bodies.
module webcrypto

fn aes_ctr_crypt(params AesCtrParams, key &CryptoKey, input []u8, decrypt bool) ![]u8 {
	if params.counter.len != 16 { return error('OperationError: Invalid counter length') }
	if params.length == 0 || params.length > 128 { return error('OperationError: Invalid length') }
	// Pinned upstream validates length but delegates full-width incrementing to EVP.
	return native_aes_ctr(decrypt, key.handle_, input, params.counter)
}
