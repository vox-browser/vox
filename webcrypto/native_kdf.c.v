// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

#pkgconfig openssl
#include "@DIR/native_kdf.h"

fn C.vox_kdf_derive(int, &char, &u8, usize, &u8, usize, &u8, usize, u32, &u8, usize) int

fn native_kdf_derive(pbkdf2 bool, hash string, key []u8, salt []u8, info []u8, iterations u32, size int) ![]u8 {
	mut output := []u8{len: size}
	if C.vox_kdf_derive(int(pbkdf2), hash.str, key.data, usize(key.len), salt.data, usize(salt.len), info.data, usize(info.len), iterations, output.data, usize(output.len)) != 1 {
		return error('OperationError: Failed to derive key')
	}
	return output
}

fn C.vox_argon2(&char, &u8, usize, &u8, usize, u32, u32, u32, &u8, usize, int, &u8, usize, int, &u8, u32) &char

fn native_argon2(params Argon2Params, password []u8, size u32) ![]u8 {
	secret := params.secret_value or { []u8{} }
	ad := params.associated_data or { []u8{} }
	mut output := []u8{len: int(size)}
	failure := C.vox_argon2(params.name.str, password.data, usize(password.len), params.nonce.data, usize(params.nonce.len), params.parallelism, params.memory, params.passes, secret.data, usize(secret.len), int(params.secret_value != none), ad.data, usize(ad.len), int(params.associated_data != none), output.data, size)
	if failure != unsafe { nil } {
		return error('OperationError: Hashing function failed: ' + unsafe { cstring_to_vstring(failure) })
	}
	return output
}
