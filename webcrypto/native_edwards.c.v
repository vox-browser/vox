// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

#pkgconfig openssl
#include "@DIR/native_edwards.h"

fn C.vox_edwards_private(&char, &u8, &usize) int
fn C.vox_edwards_public(&char, &u8, usize, &u8, &usize) int
fn C.vox_edwards_coordinate(&char, &u8, usize, &u8, usize, &u8, &usize) int

fn exchange_key_size(name string) int {
	return if name == 'X25519' { 32 } else { 56 }
}

fn native_edwards_private(name string) ![]u8 {
	mut output := []u8{len: exchange_key_size(name)}
	mut size := usize(output.len)
	if C.vox_edwards_private(name.str, output.data, &size) != 1 {
		return error('OperationError: Failed to generate private key')
	}
	return output[..int(size)].clone()
}

fn native_edwards_public(name string, private_bytes []u8) ![]u8 {
	mut output := []u8{len: exchange_key_size(name)}
	mut size := usize(output.len)
	if C.vox_edwards_public(name.str, private_bytes.data, usize(private_bytes.len), output.data, &size) != 1 {
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
