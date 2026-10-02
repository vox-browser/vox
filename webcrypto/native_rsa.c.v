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

fn C.vox_rsa_oaep(&C.VoxRsaPart, int, &char, &u8, usize, &u8, usize, &u8, &usize) int
fn C.vox_rsa_sign(&C.VoxRsaPart, &char, int, u32, &u8, usize, &u8, &usize) int
fn C.vox_rsa_verify(&C.VoxRsaPart, &char, int, u32, &u8, usize, &u8, usize) int

fn rsa_handle_parts(key &CryptoKey) []C.VoxRsaPart {
	bytes := match key.internal_handle_ {
		RsaPublicKeyHandle { [key.internal_handle_.modulus, key.internal_handle_.public_exponent] }
		RsaPrivateKeyHandle {
			[key.internal_handle_.modulus, key.internal_handle_.public_exponent,
				key.internal_handle_.private_exponent, key.internal_handle_.prime1,
				key.internal_handle_.prime2, key.internal_handle_.exponent1,
				key.internal_handle_.exponent2, key.internal_handle_.coefficient]
		}
		else { panic('Invalid RSA handle') }
	}
	mut result := []C.VoxRsaPart{cap: bytes.len}
	for part in bytes { result << C.VoxRsaPart{ bytes: part.data, length: usize(part.len) } }
	return result
}

fn rsa_operation_hash(key &CryptoKey) !string {
	hash := (key.algorithm as RsaHashedKeyAlgorithm).hash
	if hash !in ['SHA-1', 'SHA-256', 'SHA-384', 'SHA-512'] {
		return error("OperationError: Invalid hash function '${hash}'")
	}
	return hash
}

fn native_rsa_oaep(key &CryptoKey, input []u8, label []u8, decrypt bool) ![]u8 {
	parts := rsa_handle_parts(key)
	hash := rsa_operation_hash(key)!
	mut output := []u8{len: int(parts[0].length)}
	mut length := usize(output.len)
	if C.vox_rsa_oaep(parts.data, int(decrypt), hash.str, label.data, usize(label.len), input.data, usize(input.len), output.data, &length) != 1 {
		// Both source OAEP operation bodies use this exact failure text.
		return error('OperationError: Failed to encrypt')
	}
	return output[..int(length)].clone()
}

fn native_rsa_sign(key &CryptoKey, message []u8, pss bool, salt u32) ![]u8 {
	parts := rsa_handle_parts(key)
	hash := rsa_operation_hash(key)!
	mut signature := []u8{len: int(parts[0].length)}
	mut length := usize(signature.len)
	if C.vox_rsa_sign(parts.data, hash.str, int(pss), salt, message.data, usize(message.len), signature.data, &length) != 1 {
		return error('OperationError: Failed to sign message')
	}
	return signature[..int(length)].clone()
}

fn native_rsa_verify(key &CryptoKey, signature []u8, message []u8, pss bool, salt u32) !bool {
	parts := rsa_handle_parts(key)
	hash := rsa_operation_hash(key)!
	result := C.vox_rsa_verify(parts.data, hash.str, int(pss), salt, signature.data, usize(signature.len), message.data, usize(message.len))
	if result == 1 { return true }
	if result == 0 { return false }
	return error('OperationError: Failed to verify message')
}
