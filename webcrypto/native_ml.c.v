// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

$if macos {
	#pkgconfig --cflags openssl
} $else {
	#pkgconfig openssl
}
#include "@DIR/native_ml.h"

fn C.vox_ml_generate(&char, &char, &u8, uint, &u8, &uint, &u8, &uint, &u8, &uint) &char
fn C.vox_mlkem_encapsulate(&char, &u8, uint, &u8, &uint, &u8, &uint) &char
fn C.vox_mlkem_decapsulate(&char, &u8, uint, &u8, uint, &u8, uint, &u8, uint, &u8, &uint) &char

fn mlkem_sizes(name string) !(int, int, int) {
	return match name {
		'ML-KEM-512' {
			(800), 1632, 768
		}
		'ML-KEM-768' {
			(1184), 2400, 1088
		}
		'ML-KEM-1024' {
			(1568), 3168, 1568
		}
		else { return error('NotSupportedError: Invalid algorithm') }
	}
}

fn native_mlkem_generate(name string, seed []u8) !MlkemPrivateKeyHandle {
	pub_size, priv_size, _ := mlkem_sizes(name)!
	mut public_bytes := []u8{len: pub_size}
	mut private_bytes := []u8{len: priv_size}
	mut seed_out := []u8{len: 64}
	mut public_length := uint(pub_size)
	mut private_length := uint(priv_size)
	mut seed_length := uint(64)
	failure := C.vox_ml_generate(name.str, c'seed', seed.data, uint(seed.len), public_bytes.data, &public_length, private_bytes.data, &private_length, seed_out.data, &seed_length)
	if failure != unsafe { nil } {
		return error('OperationError: Key generation failed: ${unsafe { cstring_to_vstring(failure) }}')
	}
	return MlkemPrivateKeyHandle{ seed: seed_out[..int(seed_length)].clone(), public_key: public_bytes[..int(public_length)].clone(), private_key: private_bytes[..int(private_length)].clone() }
}

fn native_mlkem_encapsulate(name string, public_bytes []u8) !EncapsulatedBits {
	_, _, cipher_size := mlkem_sizes(name)!
	mut ciphertext := []u8{len: cipher_size}
	mut shared_bytes := []u8{len: 32}
	mut cipher_length := uint(cipher_size)
	mut shared_length := uint(32)
	failure := C.vox_mlkem_encapsulate(name.str, public_bytes.data, uint(public_bytes.len), ciphertext.data, &cipher_length, shared_bytes.data, &shared_length)
	if failure != unsafe { nil } {
		return error('OperationError: Key encapsulation failed: ${unsafe { cstring_to_vstring(failure) }}')
	}
	return EncapsulatedBits{ shared_key: shared_bytes[..int(shared_length)].clone(), ciphertext: ciphertext[..int(cipher_length)].clone() }
}

fn native_mlkem_decapsulate(name string, private_key MlkemPrivateKeyHandle, ciphertext []u8) ![]u8 {
	mut shared_bytes := []u8{len: 32}
	mut shared_length := uint(32)
	failure := C.vox_mlkem_decapsulate(name.str, private_key.seed.data, uint(private_key.seed.len), private_key.public_key.data, uint(private_key.public_key.len), private_key.private_key.data, uint(private_key.private_key.len), ciphertext.data, uint(ciphertext.len), shared_bytes.data, &shared_length)
	if failure != unsafe { nil } {
		return error('OperationError: Key decapsulation failed: ${unsafe { cstring_to_vstring(failure) }}')
	}
	return shared_bytes[..int(shared_length)].clone()
}

fn C.vox_mldsa_sign(&char, &u8, uint, &u8, uint, &u8, uint, &u8, uint, &u8, uint, &u8, &uint) int
fn C.vox_mldsa_verify(&char, &u8, uint, &u8, uint, &u8, uint, &u8, uint) int

fn mldsa_sizes(name string) !(int, int, int) {
	return match name {
		'ML-DSA-44' { 1312, 2560, 2420 }
		'ML-DSA-65' { 1952, 4032, 3309 }
		'ML-DSA-87' { 2592, 4896, 4627 }
		else { return error('NotSupportedError: Invalid algorithm') }
	}
}

fn native_mldsa_generate(name string, seed []u8) !MldsaPrivateKeyHandle {
	pub_size, priv_size, _ := mldsa_sizes(name)!
	mut public_bytes := []u8{len: pub_size}
	mut private_bytes := []u8{len: priv_size}
	mut seed_out := []u8{len: 32}
	mut public_length := uint(pub_size)
	mut private_length := uint(priv_size)
	mut seed_length := uint(32)
	failure := C.vox_ml_generate(name.str, c'seed', seed.data, uint(seed.len), public_bytes.data, &public_length, private_bytes.data, &private_length, seed_out.data, &seed_length)
	if failure != unsafe { nil } { return error('OperationError: Key generation failed') }
	return MldsaPrivateKeyHandle{ seed: seed_out[..int(seed_length)].clone(), public_key: public_bytes[..int(public_length)].clone(), private_key: private_bytes[..int(private_length)].clone() }
}

fn native_mldsa_sign(name string, key MldsaPrivateKeyHandle, message []u8, context []u8) ![]u8 {
	_, _, size := mldsa_sizes(name)!
	mut signature := []u8{len: size}
	mut length := uint(size)
	if C.vox_mldsa_sign(name.str, key.seed.data, uint(key.seed.len), key.public_key.data, uint(key.public_key.len), key.private_key.data, uint(key.private_key.len), context.data, uint(context.len), message.data, uint(message.len), signature.data, &length) != 1 {
		return error('OperationError: Failed to sign message')
	}
	return signature[..int(length)].clone()
}

fn native_mldsa_verify(name string, key MldsaPublicKeyHandle, signature []u8, message []u8, context []u8) !bool {
	result := C.vox_mldsa_verify(name.str, key.public_key.data, uint(key.public_key.len), context.data, uint(context.len), signature.data, uint(signature.len), message.data, uint(message.len))
	if result == 1 { return true }
	if result == 0 { return false }
	return error('OperationError: Failed to verify message')
}
