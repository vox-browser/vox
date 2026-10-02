// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

#pkgconfig openssl
#include "@DIR/native_ec.h"

fn C.vox_ec_private(&char, &u8, usize) int
fn C.vox_ec_public(&char, &u8, usize, &u8, &u8, usize) int
fn C.vox_ec_valid(&char, &u8, usize, &u8, usize, &u8, usize, int) int

fn ec_scalar_size(curve string) int {
	return match curve {
		'P-256' { 32 }
		'P-384' { 48 }
		'P-521' { 66 }
		else { 0 }
	}
}

fn native_ec_generate(curve string) !EcPrivateKeyHandle {
	mut d := []u8{len: ec_scalar_size(curve)}
	if C.vox_ec_private(curve.str, d.data, usize(d.len)) != 1 {
		return error('EC generation failed')
	}
	return EcPrivateKeyHandle{ d: d, public_key: native_ec_public(curve, d)! }
}

fn native_ec_public(curve string, d []u8) !EcPublicKeyHandle {
	mut x := []u8{len: ec_scalar_size(curve)}
	mut y := []u8{len: x.len}
	if C.vox_ec_public(curve.str, d.data, usize(d.len), x.data, y.data, usize(x.len)) != 1 {
		return error('EC public key generation failed')
	}
	return EcPublicKeyHandle{ x: x, y: y }
}

fn native_ec_valid(curve string, point EcPublicKeyHandle, d ?[]u8) !bool {
	private_bytes := d or { []u8{} }
	result := C.vox_ec_valid(curve.str, point.x.data, usize(point.x.len), point.y.data, usize(point.y.len), private_bytes.data, usize(private_bytes.len), int(d != none))
	if result < 0 { return error('DataError: Failed to verify key') }
	return result == 1
}
