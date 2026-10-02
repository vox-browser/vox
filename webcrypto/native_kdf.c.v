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
