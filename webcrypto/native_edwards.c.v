// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

#pkgconfig openssl
#include "@DIR/native_edwards.h"

fn C.vox_edwards_private(&char, &u8, &usize) int
fn C.vox_edwards_public(&char, &u8, usize, &u8, &usize) int
fn C.vox_edwards_coordinate(&char, &u8, usize, &u8, usize, &u8, &usize) int
fn C.vox_edwards_sign(&char, &u8, usize, &u8, usize, &u8, usize, &u8, &usize) int
fn C.vox_edwards_verify(&char, &u8, usize, &u8, usize, &u8, usize, &u8, usize) int

fn exchange_key_size(name string) int {
	return match name {
		'X25519', 'Ed25519' { 32 }
		'Ed448' { 57 }
		else { 56 }
	}
}

fn native_edwards_private(name string) ![]u8 {
	mut output := []u8{len: exchange_key_size(name)}
	mut size := usize(output.len)
	if C.vox_edwards_private(name.to_upper().str, output.data, &size) != 1 {
		return error('OperationError: Failed to generate private key')
	}
	return output[..int(size)].clone()
}

fn native_edwards_public(name string, private_bytes []u8) ![]u8 {
	mut output := []u8{len: exchange_key_size(name)}
	mut size := usize(output.len)
	if C.vox_edwards_public(name.to_upper().str, private_bytes.data, usize(private_bytes.len), output.data, &size) != 1 {
		return error('OperationError: Failed to generate public key')
	}
	return output[..int(size)].clone()
}

fn native_edwards_coordinate(name string, private_bytes []u8, public_bytes []u8) ![]u8 {
	mut output := []u8{len: exchange_key_size(name)}
	mut size := usize(output.len)
	if C.vox_edwards_coordinate(name.str, private_bytes.data, usize(private_bytes.len), public_bytes.data, usize(public_bytes.len), output.data, &size) != 1 {
		return error('OperationError: Failed to compute secret')
	}
	return output[..int(size)].clone()
}

fn native_ed448_sign(private_bytes []u8, message []u8, context []u8) ![]u8 {
	mut signature := []u8{len: 114}
	mut size := usize(signature.len)
	if C.vox_edwards_sign(c'ED448', private_bytes.data, usize(private_bytes.len), message.data, usize(message.len), context.data, usize(context.len), signature.data, &size) != 1 {
		return error('OperationError: Failed to sign message')
	}
	return signature[..int(size)].clone()
}

fn native_ed448_verify(public_bytes []u8, signature []u8, message []u8, context []u8) !bool {
	result := C.vox_edwards_verify(c'ED448', public_bytes.data, usize(public_bytes.len), signature.data, usize(signature.len), message.data, usize(message.len), context.data, usize(context.len))
	if result < 0 {
		failure := match result {
			-1 { 'ptr failed' }
			-2 { 'EVP_MD_CTX_new() failed' }
			-3 {
				'EVP_DigestVerifyInit_ex(ctx.ptr(), nullptr, nullptr, nullptr, nullptr, key.ptr(), params) failed'
			}
			else { 'res failed' }
		}
		return error('OperationError: ${failure}')
	}
	return result == 1
}
