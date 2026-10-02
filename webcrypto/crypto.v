// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Crypto/Crypto.{h,cpp}.
module webcrypto

import crypto.rand

pub const maximum_random_values_length = 65_536

// ArrayBufferView includes DataView and floating-point typed arrays, while
// getRandomValues accepts only the integer typed-array kinds below.
pub enum RandomValuesArrayKind {
	int8
	uint8
	uint8_clamped
	int16
	uint16
	int32
	uint32
	bigint64
	biguint64
	float32
	float64
	data_view
}

pub struct RandomValuesArrayView {
pub:
	kind          RandomValuesArrayKind
	byte_offset   int
	byte_length   int
	out_of_bounds bool
pub mut:
	buffer []u8
}

pub fn RandomValuesArrayView.create(kind RandomValuesArrayKind, buffer []u8, byte_offset int, byte_length int) !RandomValuesArrayView {
	if byte_offset < 0 || byte_length < 0 || byte_offset > buffer.len
		|| byte_length > buffer.len - byte_offset {
		return error('InvalidStateError: TypedArray is out of bounds')
	}
	return RandomValuesArrayView{
		kind:        kind
		buffer:      buffer
		byte_offset: byte_offset
		byte_length: byte_length
	}
}

pub fn random_values_array_kind_is_allowed(kind RandomValuesArrayKind) bool {
	return kind in [.int8, .uint8, .uint8_clamped, .int16, .uint16, .int32, .uint32, .bigint64,
		.biguint64]
}

@[heap]
pub struct Crypto {
mut:
	subtle_ &SubtleCrypto = unsafe { nil }
}

pub fn Crypto.create() &Crypto {
	return &Crypto{
		subtle_: SubtleCrypto.create()
	}
}

pub fn (crypto &Crypto) subtle() &SubtleCrypto {
	return crypto.subtle_
}

// https://w3c.github.io/webcrypto/#Crypto-method-getRandomValues
pub fn (crypto &Crypto) get_random_values(mut destination []u8) ![]u8 {
	_ = crypto
	if destination.len > maximum_random_values_length {
		return error('QuotaExceededError: Byte length exceeds 65536')
	}
	random := rand.bytes(destination.len) or {
		return error('OperationError: Unable to obtain secure random bytes: ${err}')
	}
	copy(mut destination, random)
	return destination
}

// Typed ArrayBufferView form of getRandomValues. The backing slice models the
// viewed ArrayBuffer; only the view's byte range is overwritten.
pub fn (crypto &Crypto) get_random_values_view(mut destination RandomValuesArrayView) !RandomValuesArrayView {
	invalid := destination.out_of_bounds || destination.byte_offset < 0 || destination.byte_length < 0
		|| destination.byte_offset > destination.buffer.len
		|| destination.byte_length > destination.buffer.len - destination.byte_offset
	random := crypto.get_random_values_for_view(destination.kind, invalid, u64(destination.byte_length))!
	for index, byte in random { destination.buffer[destination.byte_offset + index] = byte }
	return destination
}

// The native engine supplies its actual witness/view length. The source creates
// random bytes before overwriting that view; no JS property or payload models it.
pub fn (crypto &Crypto) get_random_values_for_view(kind RandomValuesArrayKind, out_of_bounds bool, byte_length u64) ![]u8 {
	_ = crypto
	if !random_values_array_kind_is_allowed(kind) {
		return error('TypeMismatchError: array must be one of Int8Array, Uint8Array, Uint8ClampedArray, Int16Array, Uint16Array, Int32Array, Uint32Array, BigInt64Array, or BigUint64Array')
	}
	if out_of_bounds {
		return error("InvalidStateError: TypedArray contains a property which references a value at an index not contained within its buffer's bounds")
	}
	if byte_length > maximum_random_values_length {
		return error("QuotaExceededError: array's byteLength may not be greater than 65536")
	}
	return rand.bytes(int(byte_length)) or { return error('OperationError: Unable to obtain secure random bytes: ${err}') }
}

// https://w3c.github.io/webcrypto/#Crypto-method-randomUUID
pub fn (crypto &Crypto) random_uuid() !string {
	_ = crypto
	return generate_random_uuid()
}

pub fn generate_random_uuid() !string {
	mut bytes := rand.bytes(16) or {
		return error('OperationError: Unable to obtain secure random bytes: ${err}')
	}
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	hex := bytes.hex()
	return '${hex[..8]}-${hex[8..12]}-${hex[12..16]}-${hex[16..20]}-${hex[20..]}'
}
