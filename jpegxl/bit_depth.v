// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct BitDepth {
pub:
	floating_point  bool
	bits_per_sample u32 = 8
	exponent_bits   u32
}

pub fn (mut b BitReader) read_bit_depth() !BitDepth {
	floating := b.read(1)! != 0
	choices := if floating {
		[U32Code{ offset: 32 }, U32Code{ offset: 16 }, U32Code{ offset: 24 },
			U32Code{ bits: 6, offset: 1 }]!
	} else {
		[U32Code{ offset: 8 }, U32Code{ offset: 10 }, U32Code{ offset: 12 },
			U32Code{ bits: 6, offset: 1 }]!
	}
	bits := b.read_u32(choices)!
	exponent := if floating { u32(b.read(4)! + 1) } else { u32(0) }
	if floating {
		if exponent < 2 || exponent > 8 { return error('Invalid JPEG XL float exponent') }
		mantissa := int(bits) - int(exponent) - 1
		if mantissa < 2 || mantissa > 23 { return error('Invalid JPEG XL float mantissa') }
	} else if bits > 31 {
		return error('Invalid JPEG XL integer depth')
	}
	return BitDepth{ floating_point: floating, bits_per_sample: bits, exponent_bits: exponent }
}
