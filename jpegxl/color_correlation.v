// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

pub struct ColorCorrelationParams {
pub:
	color_factor       u32 = 84
	base_correlation_x f32
	base_correlation_b f32 = 1
	ytox_lf            i32
	ytob_lf            i32
}

pub fn (mut reader BitReader) read_color_correlation_params() !ColorCorrelationParams {
	if reader.read(1)! == 1 { return ColorCorrelationParams{} }
	color_factor := reader.read_u32([U32Code{ offset: 84 }, U32Code{ offset: 256 },
		U32Code{ bits: 8, offset: 2 }, U32Code{ bits: 16, offset: 258 }]!)!
	// Source f16::from_bits reads both fields before checking either for finiteness.
	x_bits := u32(reader.read(16)!)
	b_bits := u32(reader.read(16)!)
	base_x := finite_half_float(x_bits)!
	base_b := finite_half_float(b_bits)!
	if math.abs(base_x) > f32(4) || math.abs(base_b) > f32(4) {
		return error('JPEG XL base color correlation is out of range')
	}
	ytox := i32(reader.read(8)!) - 128
	ytob := i32(reader.read(8)!) - 128
	return ColorCorrelationParams{
		color_factor:       color_factor
		base_correlation_x: base_x
		base_correlation_b: base_b
		ytox_lf:            ytox
		ytob_lf:            ytob
	}
}

pub fn (params ColorCorrelationParams) y_to_x(factor i32) f32 {
	return params.base_correlation_x + f32(factor) / f32(params.color_factor)
}

pub fn (params ColorCorrelationParams) y_to_b(factor i32) f32 {
	return params.base_correlation_b + f32(factor) / f32(params.color_factor)
}

pub fn (params ColorCorrelationParams) y_to_x_lf() f32 {
	return params.y_to_x(params.ytox_lf)
}

pub fn (params ColorCorrelationParams) y_to_b_lf() f32 {
	return params.y_to_b(params.ytob_lf)
}
