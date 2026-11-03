// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

$if macos {
	#pkgconfig --cflags openssl
} $else {
	#pkgconfig openssl
}
#include "@DIR/native_ec.h"

fn C.vox_ec_private(&char, &u8, uint) int
fn C.vox_ec_public(&char, &u8, uint, &u8, &u8, uint) int
fn C.vox_ec_valid(&char, &u8, uint, &u8, uint, &u8, uint, int) int

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
	if C.vox_ec_private(curve.str, d.data, uint(d.len)) != 1 {
		return error('EC generation failed')
	}
	return EcPrivateKeyHandle{ d: d, public_key: native_ec_public(curve, d)! }
}

fn native_ec_public(curve string, d []u8) !EcPublicKeyHandle {
	mut x := []u8{len: ec_scalar_size(curve)}
	mut y := []u8{len: x.len}
	if C.vox_ec_public(curve.str, d.data, uint(d.len), x.data, y.data, uint(x.len)) != 1 {
		return error('EC public key generation failed')
	}
	return EcPublicKeyHandle{ x: x, y: y }
}

fn native_ec_valid(curve string, point EcPublicKeyHandle, d ?[]u8) !bool {
	private_bytes := d or { []u8{} }
	result := C.vox_ec_valid(curve.str, point.x.data, uint(point.x.len), point.y.data, uint(point.y.len), private_bytes.data, uint(private_bytes.len), int(d != none))
	if result < 0 { return error('DataError: Failed to verify key') }
	return result == 1
}

fn C.vox_ec_sign(&char, &u8, uint, &u8, uint, &u8, uint) &char
fn C.vox_ec_verify(&char, &u8, uint, &u8, uint, &u8, uint, &int) &char
fn C.vox_ec_coordinate(&char, &u8, uint, &u8, uint, &u8, uint, &u8, &u8, uint) &char

fn ec_point_to_uncompressed(point EcPublicKeyHandle) []u8 {
	mut bytes := [u8(4)]
	bytes << point.x
	bytes << point.y
	return bytes
}

fn native_ec_sign(curve string, d []u8, digest []u8) ![]u8 {
	size := ec_scalar_size(curve)
	mut signature := []u8{len: size * 2}
	failure := C.vox_ec_sign(curve.str, d.data, uint(d.len), digest.data, uint(digest.len), signature.data, uint(size))
	if failure != unsafe { nil } {
		return error('OperationError: ' + unsafe { cstring_to_vstring(failure) })
	}
	return signature
}

fn native_ec_verify(curve string, point EcPublicKeyHandle, signature []u8, digest []u8) !bool {
	bytes := ec_point_to_uncompressed(point)
	mut result := 0
	failure := C.vox_ec_verify(curve.str, bytes.data, uint(bytes.len), digest.data, uint(digest.len), signature.data, uint(signature.len / 2), &result)
	if failure != unsafe { nil } {
		return error('OperationError: ' + unsafe { cstring_to_vstring(failure) })
	}
	return result == 1
}

fn native_ec_coordinate(curve string, d []u8, point EcPublicKeyHandle) !EcPublicKeyHandle {
	mut x := []u8{len: ec_scalar_size(curve)}
	mut y := []u8{len: x.len}
	failure := C.vox_ec_coordinate(curve.str, d.data, uint(d.len), point.x.data, uint(point.x.len), point.y.data, uint(point.y.len), x.data, y.data, uint(x.len))
	if failure != unsafe { nil } {
		return error('OperationError: Failed to compute secret: ' + unsafe { cstring_to_vstring(failure) })
	}
	return EcPublicKeyHandle{ x: x, y: y }
}

fn C.vox_ec_decompress(&char, &u8, uint, &u8, &u8, uint) int

fn native_ec_decompress(bytes []u8) !EcPublicKeyHandle {
	size := bytes.len - 1
	curve := match size {
		32 { 'P-256' }
		48 { 'P-384' }
		66 { 'P-521' }
		else { return error('DataError: Unsupported curve for compressed EC point') }
	}
	mut x := []u8{len: size}
	mut y := []u8{len: size}
	if C.vox_ec_decompress(curve.str, bytes.data, uint(bytes.len), x.data, y.data, uint(size)) != 1 {
		return error('DataError: Failed to decompress EC point')
	}
	return EcPublicKeyHandle{ x: x, y: y }
}
