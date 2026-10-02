// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

// LibCrypto uses OpenSSL 3 EVP_MAC for KMAC. Keep the same provider backend.
#pkgconfig openssl
#include "@DIR/native_crypto.h"

fn C.vox_kmac(&char, &u8, usize, &u8, usize, &u8, usize, &u8, usize) int

fn native_kmac(name string, key []u8, message []u8, customization []u8, output_size int) ![]u8 {
	mut output := []u8{len: output_size}
	if C.vox_kmac(name.str, key.data, usize(key.len), message.data, usize(message.len),
		customization.data, usize(customization.len), output.data, usize(output.len)) != 1 {
		return error('OperationError: KMAC operation failed')
	}
	return output
}
