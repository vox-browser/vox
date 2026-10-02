// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

#pkgconfig openssl
#include "@DIR/native_rsa.h"

struct C.VoxRsaPart {
mut:
	bytes  &u8
	length usize
}

fn C.vox_rsa_generate(usize, &u8, usize, &C.VoxRsaPart) int

fn native_rsa_generate(bits u32, exponent []u8) !RsaPrivateKeyHandle {
	size := int((u64(bits) + 7) / 8)
	mut bytes := [][]u8{len: 7}
	mut parts := []C.VoxRsaPart{len: 7}
	for i in 0 .. 7 {
		bytes[i] = []u8{len: size}
		parts[i] = C.VoxRsaPart{ bytes: bytes[i].data, length: usize(size) }
	}
	if C.vox_rsa_generate(usize(bits), exponent.data, usize(exponent.len), parts.data) != 1 {
		return error('RSA key generation failed')
	}
	return RsaPrivateKeyHandle{
		modulus:          bytes[0][..int(parts[0].length)].clone()
		private_exponent: bytes[1][..int(parts[1].length)].clone()
		public_exponent:  unsigned_big_integer_bytes(exponent)
		prime1:           bytes[2][..int(parts[2].length)].clone()
		prime2:           bytes[3][..int(parts[3].length)].clone()
		exponent1:        bytes[4][..int(parts[4].length)].clone()
		exponent2:        bytes[5][..int(parts[5].length)].clone()
		coefficient:      bytes[6][..int(parts[6].length)].clone()
	}
}
