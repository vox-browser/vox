// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

pub struct DctQuantWeightParams {
pub:
	parameters [3][]f32
}

// Unlike serialized metadata floats, quantization tables use util::f16 directly.
// Preserve its infinities and quiet NaNs here; matrix validation is a later step.
fn (mut reader BitReader) read_quantization_half() !f32 {
	bits := u32(reader.read(16)!)
	if bits & 0x7c00 == 0x7c00 {
		sign := (bits & 0x8000) << 16
		fraction := (bits & 1023) << 13
		quiet := if fraction == 0 { u32(0) } else { u32(0x400000) }
		return math.f32_from_bits(sign | 0x7f800000 | fraction | quiet)
	}
	return finite_half_float(bits)
}

pub fn (mut reader BitReader) read_dct_quant_weight_params() !DctQuantWeightParams {
	count := int(reader.read(4)!) + 1
	mut parameters := [3][]f32{}
	for c in 0 .. 3 {
		mut row := []f32{len: count}
		for i in 0 .. count { row[i] = reader.read_quantization_half()! }
		// The source checks the first weight after consuming the complete row.
		if row[0] < f32(1e-8) { return error('JPEG XL HF quantization factor is too small') }
		row[0] *= f32(64)
		parameters[c] = row
	}
	return DctQuantWeightParams{ parameters: parameters }
}
