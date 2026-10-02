// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

#pkgconfig openssl
#include "@DIR/native_ml.h"

fn C.vox_ml_generate(&char, &char, &u8, usize, &u8, &usize, &u8, &usize, &u8, &usize) &char
fn C.vox_mlkem_encapsulate(&char, &u8, usize, &u8, &usize, &u8, &usize) &char
fn C.vox_mlkem_decapsulate(&char, &u8, usize, &u8, usize, &u8, usize, &u8, usize, &u8, &usize) &char

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
	mut public_length := usize(pub_size)
	mut private_length := usize(priv_size)
	mut seed_length := usize(64)
	failure := C.vox_ml_generate(name.str, c'seed', seed.data, usize(seed.len), public_bytes.data, &public_length, private_bytes.data, &private_length, seed_out.data, &seed_length)
	if failure != unsafe { nil } {
		return error('OperationError: Key generation failed: ${unsafe { cstring_to_vstring(failure) }}')
	}
	return MlkemPrivateKeyHandle{ seed: seed_out[..int(seed_length)].clone(), public_key: public_bytes[..int(public_length)].clone(), private_key: private_bytes[..int(private_length)].clone() }
}

fn native_mlkem_encapsulate(name string, public_bytes []u8) !EncapsulatedBits {
	_, _, cipher_size := mlkem_sizes(name)!
	mut ciphertext := []u8{len: cipher_size}
	mut shared_bytes := []u8{len: 32}
	mut cipher_length := usize(cipher_size)
	mut shared_length := usize(32)
	failure := C.vox_mlkem_encapsulate(name.str, public_bytes.data, usize(public_bytes.len), ciphertext.data, &cipher_length, shared_bytes.data, &shared_length)
	if failure != unsafe { nil } {
		return error('OperationError: Key encapsulation failed: ${unsafe { cstring_to_vstring(failure) }}')
	}
	return EncapsulatedBits{ shared_key: shared_bytes[..int(shared_length)].clone(), ciphertext: ciphertext[..int(cipher_length)].clone() }
}

fn native_mlkem_decapsulate(name string, private_key MlkemPrivateKeyHandle, ciphertext []u8) ![]u8 {
	mut shared_bytes := []u8{len: 32}
	mut shared_length := usize(32)
	failure := C.vox_mlkem_decapsulate(name.str, private_key.seed.data, usize(private_key.seed.len), private_key.public_key.data, usize(private_key.public_key.len), private_key.private_key.data, usize(private_key.private_key.len), ciphertext.data, usize(ciphertext.len), shared_bytes.data, &shared_length)
	if failure != unsafe { nil } {
		return error('OperationError: Key decapsulation failed: ${unsafe { cstring_to_vstring(failure) }}')
	}
	return shared_bytes[..int(shared_length)].clone()
}
