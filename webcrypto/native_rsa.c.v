// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

#pkgconfig openssl
#include "@DIR/native_rsa.h"

struct C.VoxRsaPart {
mut:
	bytes  &u8
	length uint
}

fn C.vox_rsa_generate(uint, &u8, uint, &C.VoxRsaPart) int

fn native_rsa_generate(bits u32, exponent []u8) !RsaPrivateKeyHandle {
	size := int((u64(bits) + 7) / 8)
	mut bytes := [][]u8{len: 7}
	mut parts := []C.VoxRsaPart{len: 7}
	for i in 0 .. 7 {
		bytes[i] = []u8{len: size}
		parts[i] = C.VoxRsaPart{ bytes: bytes[i].data, length: uint(size) }
	}
	if C.vox_rsa_generate(uint(bits), exponent.data, uint(exponent.len), parts.data) != 1 {
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

fn C.vox_rsa_oaep(&C.VoxRsaPart, int, &char, &u8, uint, &u8, uint, &u8, &uint) int
fn C.vox_rsa_sign(&C.VoxRsaPart, &char, int, u32, &u8, uint, &u8, &uint) int
fn C.vox_rsa_verify(&C.VoxRsaPart, &char, int, u32, &u8, uint, &u8, uint) int

fn rsa_parts_from_handle(handle CryptoKeyInternalHandle) []C.VoxRsaPart {
	bytes := match handle {
		RsaPublicKeyHandle { [handle.modulus, handle.public_exponent] }
		RsaPrivateKeyHandle {
			[handle.modulus, handle.public_exponent, handle.private_exponent, handle.prime1,
				handle.prime2, handle.exponent1, handle.exponent2, handle.coefficient]
		}
		else { panic('Invalid RSA handle') }
	}
	mut result := []C.VoxRsaPart{cap: bytes.len}
	for part in bytes { result << C.VoxRsaPart{ bytes: part.data, length: uint(part.len) } }
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
	parts := rsa_parts_from_handle(key.internal_handle_)
	hash := rsa_operation_hash(key)!
	mut output := []u8{len: int(parts[0].length)}
	mut length := uint(output.len)
	if C.vox_rsa_oaep(parts.data, int(decrypt), hash.str, label.data, uint(label.len), input.data, uint(input.len), output.data, &length) != 1 {
		// Both source OAEP operation bodies use this exact failure text.
		return error('OperationError: Failed to encrypt')
	}
	return output[..int(length)].clone()
}

fn native_rsa_sign(key &CryptoKey, message []u8, pss bool, salt u32) ![]u8 {
	parts := rsa_parts_from_handle(key.internal_handle_)
	hash := rsa_operation_hash(key)!
	mut signature := []u8{len: int(parts[0].length)}
	mut length := uint(signature.len)
	if C.vox_rsa_sign(parts.data, hash.str, int(pss), salt, message.data, uint(message.len), signature.data, &length) != 1 {
		return error('OperationError: Failed to sign message')
	}
	return signature[..int(length)].clone()
}

fn native_rsa_verify(key &CryptoKey, signature []u8, message []u8, pss bool, salt u32) !bool {
	parts := rsa_parts_from_handle(key.internal_handle_)
	hash := rsa_operation_hash(key)!
	result := C.vox_rsa_verify(parts.data, hash.str, int(pss), salt, signature.data, uint(signature.len), message.data, uint(message.len))
	if result == 1 { return true }
	if result == 0 { return false }
	return error('OperationError: Failed to verify message')
}

fn C.vox_rsa_valid(&C.VoxRsaPart, int) int

fn validate_rsa_handle(handle CryptoKeyInternalHandle, private_key bool) ! {
	parts := rsa_parts_from_handle(handle)
	result := C.vox_rsa_valid(parts.data, int(private_key))
	if result < 0 { return error('DataError: Failed to verify key') }
	if result == 0 { return error('DataError: Invalid key') }
}
