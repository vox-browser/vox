// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math
import strings

pub struct U32Code {
pub:
	bits   int
	offset u32
}

pub fn (mut b BitReader) read_u32(choices [4]U32Code) !u32 {
	selector := int(b.read(2)!)
	code := choices[selector]
	if code.bits < 0 || code.bits > 32 { return error('Invalid JPEG XL integer coder') }
	value := b.read(code.bits)!
	if value + u64(code.offset) > u64(0xffffffff) {
		return error('JPEG XL integer overflow')
	}
	return u32(value) + code.offset
}

pub fn (mut b BitReader) read_u64() !u64 {
	selector := b.read(2)!
	match selector {
		0 { return 0 }
		1 { return 1 + b.read(4)! }
		2 { return 17 + b.read(8)! }
		else {
			mut result := b.read(12)!
			mut shift := 12
			for b.read(1)! != 0 {
				if shift == 60 { return result | (b.read(4)! << 60) }
				result |= b.read(8)! << shift
				shift += 8
			}
			return result
		}
	}
}

pub fn unpack_signed(value u32) i32 {
	return if value & 1 == 0 { i32(value >> 1) } else { -i32(value >> 1) - 1 }
}

// Serialized half floats must be finite, including in fields later ignored by the caller.
pub fn (mut b BitReader) read_f16() !f32 {
	value := u32(b.read(16)!)
	sign := (value & 0x8000) << 16
	exponent := (value >> 10) & 31
	mut fraction := value & 1023
	if exponent == 31 { return error('Nonfinite JPEG XL half float') }
	if exponent != 0 {
		return math.f32_from_bits(sign | ((exponent + 112) << 23) | (fraction << 13))
	}
	if fraction == 0 { return math.f32_from_bits(sign) }
	// Preserve jxl 0.7.0's subnormal exponent (one below IEEE binary16).
	// This compatibility behavior is covered by the exhaustive source fixture.
	mut normalized_exponent := 112
	for fraction & 1024 == 0 {
		fraction <<= 1
		normalized_exponent--
	}
	return math.f32_from_bits(sign | (u32(normalized_exponent) << 23) | ((fraction & 1023) << 13))
}

// The source maps each serialized byte to its Latin-1 scalar, rather than UTF-8 decoding.
pub fn (mut b BitReader) read_name() !string {
	length := int(b.read_u32([U32Code{}, U32Code{ bits: 4 }, U32Code{ bits: 5, offset: 16 },
		U32Code{ bits: 10, offset: 48 }]!)!)
	if length > b.available_bits() / 8 { return error('Truncated JPEG XL name') }
	mut result := strings.new_builder(length * 2)
	for _ in 0 .. length {
		value := u8(b.read(8)!)
		if value < 128 {
			result.write_u8(value)
		} else {
			result.write_u8(0xc0 | (value >> 6))
			result.write_u8(0x80 | (value & 63))
		}
	}
	return result.str()
}

pub fn (mut b BitReader) skip_extensions() ! {
	selector := b.read_u64()!
	mut total := u64(0)
	for i in 0 .. 64 {
		if selector & (u64(1) << i) != 0 {
			size := b.read_u64()!
			if size > ~u64(0) - total { return error('JPEG XL extension size overflow') }
			total += size
		}
	}
	if total > u64(b.available_bits()) { return error('Truncated JPEG XL extensions') }
	b.skip(int(total))!
}
