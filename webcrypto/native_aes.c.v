// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

$if macos {
	#pkgconfig --cflags openssl
} $else {
	#pkgconfig openssl
}
#include "@DIR/native_aes.h"

fn C.vox_aes_cbc(int, int, &u8, uint, &u8, uint, &u8, &u8, &uint) int

fn native_aes_cbc(decrypt bool, no_padding bool, key []u8, input []u8, iv []u8) ![]u8 {
	mut output := []u8{len: input.len + 16}
	mut size := uint(output.len)
	if C.vox_aes_cbc(int(decrypt), int(no_padding), key.data, uint(key.len), input.data, uint(input.len), iv.data, output.data, &size) != 1 {
		action := if decrypt { 'decrypt' } else { 'encrypt' }
		return error('OperationError: Failed to ${action}')
	}
	return output[..int(size)].clone()
}

fn C.vox_aes_ctr(int, &u8, uint, &u8, uint, &u8, &u8, &uint) int

fn native_aes_ctr(decrypt bool, key []u8, input []u8, iv []u8) ![]u8 {
    mut output := []u8{len: input.len + 16}
    mut size := uint(output.len)
    if C.vox_aes_ctr(int(decrypt), key.data, uint(key.len), input.data, uint(input.len), iv.data, output.data, &size) != 1 {
        action := if decrypt { 'Decryption' } else { 'Encryption' }
        return error('OperationError: ${action} failed')
    }
    return output[..int(size)].clone()
}

fn C.vox_aes_gcm(int, &u8, uint, &u8, uint, &u8, uint, &u8, uint, &u8, uint, &u8, &uint) int

fn native_aes_gcm(decrypt bool, key []u8, input []u8, iv []u8, aad []u8, tag []u8, tag_size int) ![]u8 {
    mut output := []u8{len: input.len + tag_size + 16}
    mut size := uint(output.len)
    if C.vox_aes_gcm(int(decrypt), key.data, uint(key.len), input.data, uint(input.len), iv.data, uint(iv.len), aad.data, uint(aad.len), tag.data, uint(tag_size), output.data, &size) != 1 {
        action := if decrypt { 'Decryption' } else { 'Encryption' }
        return error('OperationError: ${action} failed')
    }
    return output[..int(size)].clone()
}

fn C.vox_aes_kw(int, &u8, uint, &u8, uint, &u8, &uint) int

fn native_aes_kw(decrypt bool, key []u8, input []u8) ![]u8 {
    mut output := []u8{len: input.len + 8}
    mut size := uint(output.len)
    if C.vox_aes_kw(int(decrypt), key.data, uint(key.len), input.data, uint(input.len), output.data, &size) != 1 {
        action := if decrypt { 'unwrap' } else { 'wrap' }
        return error('OperationError: Key ${action} failed')
    }
    return output[..int(size)].clone()
}
