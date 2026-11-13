// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

// LibCrypto uses OpenSSL 3 EVP_MAC for HMAC/KMAC and EVP_CIPHER for AES-OCB.
#include "@DIR/native_crypto.h"

fn C.vox_kmac(&char, &u8, uint, &u8, uint, &u8, uint, &u8, uint) int
fn C.vox_aes_ocb(int, &u8, uint, &u8, uint, &u8, uint, &u8, uint, uint, &u8) &char

fn native_kmac(name string, key []u8, message []u8, customization []u8, output_size int) ![]u8 {
	mut output := []u8{len: output_size}
	if C.vox_kmac(name.str, key.data, uint(key.len), message.data, uint(message.len),
		customization.data, uint(customization.len), output.data, uint(output.len)) != 1 {
		return error('OperationError: KMAC operation failed')
	}
	return output
}

fn native_aes_ocb(decrypt bool, key []u8, input []u8, iv []u8, aad []u8, tag_size int) ![]u8 {
	output_size := if decrypt { input.len - tag_size } else { input.len + tag_size }
	// EVP writes its final partial block at output + out_len; retain a valid
	// allocation even when the authenticated plaintext is empty.
	mut output := []u8{len: output_size + 16}
	failure := C.vox_aes_ocb(int(decrypt), key.data, uint(key.len), input.data, uint(input.len),
		iv.data, uint(iv.len), aad.data, uint(aad.len), uint(tag_size), output.data)
    if failure != unsafe { nil } {
        detail := unsafe { cstring_to_vstring(failure) }
		action := if decrypt { 'Decryption' } else { 'Encryption' }
		return error('OperationError: ${action} failed: ${detail}')
	}
	return output[..output_size].clone()
}

fn C.vox_hmac(&char, &u8, uint, &u8, uint, &u8, &uint) int

fn native_hmac(hash string, key []u8, message []u8) ![]u8 {
    mut output := []u8{len: 64}
    mut size := uint(output.len)
    if C.vox_hmac(hash.str, key.data, uint(key.len), message.data, uint(message.len), output.data, &size) != 1 {
        return error('OperationError: HMAC operation failed')
    }
    return output[..int(size)].clone()
}
