// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

#pkgconfig openssl
#include "@DIR/native_chacha.h"

fn C.vox_chacha20_poly1305(int, &u8, usize, &u8, usize, &u8, usize, &u8, usize, &u8, &usize) &char

fn native_chacha20_poly1305(decrypt bool, key []u8, nonce []u8, input []u8, aad []u8) ![]u8 {
	mut output := []u8{len: input.len + 16}
	mut size := usize(output.len)
	failure := C.vox_chacha20_poly1305(int(decrypt), key.data, usize(key.len), nonce.data,
		usize(nonce.len), input.data, usize(input.len), aad.data, usize(aad.len), output.data,
		&size)
	if failure != unsafe { nil } {
		detail := unsafe { cstring_to_vstring(failure) }
		action := if decrypt { 'Decryption' } else { 'Encryption' }
		return error('OperationError: ${action} failed: ${detail}')
	}
	return output[..int(size)].clone()
}
