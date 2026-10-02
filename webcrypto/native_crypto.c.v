// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

// LibCrypto uses OpenSSL 3 EVP_MAC for HMAC/KMAC and EVP_CIPHER for AES-OCB.
#pkgconfig openssl
#include "@DIR/native_crypto.h"

fn C.vox_kmac(&char, &u8, usize, &u8, usize, &u8, usize, &u8, usize) int
fn C.vox_aes_ocb(int, &u8, usize, &u8, usize, &u8, usize, &u8, usize, usize, &u8) &char

fn native_kmac(name string, key []u8, message []u8, customization []u8, output_size int) ![]u8 {
	mut output := []u8{len: output_size}
	if C.vox_kmac(name.str, key.data, usize(key.len), message.data, usize(message.len),
		customization.data, usize(customization.len), output.data, usize(output.len)) != 1 {
		return error('OperationError: KMAC operation failed')
	}
	return output
}

fn native_aes_ocb(decrypt bool, key []u8, input []u8, iv []u8, aad []u8, tag_size int) ![]u8 {
	output_size := if decrypt { input.len - tag_size } else { input.len + tag_size }
	// EVP writes its final partial block at output + out_len; retain a valid
	// allocation even when the authenticated plaintext is empty.
	mut output := []u8{len: output_size + 16}
	failure := C.vox_aes_ocb(int(decrypt), key.data, usize(key.len), input.data, usize(input.len),
		iv.data, usize(iv.len), aad.data, usize(aad.len), usize(tag_size), output.data)
    if failure != unsafe { nil } {
        detail := unsafe { cstring_to_vstring(failure) }
		action := if decrypt { 'Decryption' } else { 'Encryption' }
		return error('OperationError: ${action} failed: ${detail}')
	}
	return output[..output_size].clone()
}

fn C.vox_hmac(&char, &u8, usize, &u8, usize, &u8, &usize) int

fn native_hmac(hash string, key []u8, message []u8) ![]u8 {
    mut output := []u8{len: 64}
    mut size := usize(output.len)
    if C.vox_hmac(hash.str, key.data, usize(key.len), message.data, usize(message.len), output.data, &size) != 1 {
        return error('OperationError: HMAC operation failed')
    }
    return output[..int(size)].clone()
}
