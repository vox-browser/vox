// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

#pkgconfig openssl
#include "@DIR/native_aes.h"

fn C.vox_aes_cbc(int, int, &u8, usize, &u8, usize, &u8, &u8, &usize) int

fn native_aes_cbc(decrypt bool, no_padding bool, key []u8, input []u8, iv []u8) ![]u8 {
	mut output := []u8{len: input.len + 16}
	mut size := usize(output.len)
	if C.vox_aes_cbc(int(decrypt), int(no_padding), key.data, usize(key.len), input.data, usize(input.len), iv.data, output.data, &size) != 1 {
		action := if decrypt { 'decrypt' } else { 'encrypt' }
		return error('OperationError: Failed to ${action}')
	}
	return output[..int(size)].clone()
}
