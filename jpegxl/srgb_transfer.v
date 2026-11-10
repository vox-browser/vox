// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

pub enum SrgbTransferDirection {
	from_linear
	to_linear
}

const linear_to_srgb_p = [f32(-5.135152395e-4), 5.287254571e-3, 3.903842876e-1, 1.474205315, 7.352629620e-1]!
const linear_to_srgb_q = [f32(1.004519624e-2), 3.036675394e-1, 1.340816930, 9.258482155e-1, 2.424867759e-2]!
const srgb_to_linear_p = [f32(2.200248328e-4), 1.043637593e-2, 1.624820318e-1, 7.961564959e-1, 8.210152774e-1]!
const srgb_to_linear_q = [f32(2.631846970e-1), 1.076976492, 4.987528350e-1, -5.512498495e-2, 6.521209011e-3]!

fn srgb_rational_polynomial(x f32, p [5]f32, q [5]f32) f32 {
	mut numerator := p[4]
	mut denominator := q[4]
	for i := 3; i >= 0; i-- {
		numerator = fused_f32(numerator, x, p[i])
		denominator = fused_f32(denominator, x, q[i])
	}
	return numerator / denominator
}

// Preserve the source renderer's signed rational approximation, threshold
// comparisons and fused Horner evaluation. The source does not clamp here.
@[direct_array_access]
pub fn srgb_transfer(input FloatPlane, direction SrgbTransferDirection) !FloatPlane {
	input.validate()!
	for sample in input.samples {
		if !math.is_finite(sample) { return error('Nonfinite JPEG XL sRGB transfer sample') }
	}
	// Validation is separate so this loop has no early exit and can vectorize.
	mut result := []f32{len: input.samples.len}
	for i, sample in input.samples {
		bits := math.f32_bits(sample)
		absolute := math.f32_from_bits(bits & 0x7fffffff)
		converted := if direction == .from_linear {
			if absolute < f32(0.0031308) { absolute * f32(12.92) } else {
				srgb_rational_polynomial(f32(math.sqrt(f64(absolute))), linear_to_srgb_p, linear_to_srgb_q)
			}
		} else {
			if absolute < f32(0.04045) { absolute * (f32(1) / f32(12.92)) } else {
				srgb_rational_polynomial(absolute, srgb_to_linear_p, srgb_to_linear_q)
			}
		}
		result[i] = math.f32_from_bits((math.f32_bits(converted) & 0x7fffffff) | (bits & 0x80000000))
	}
	return FloatPlane{ width: input.width, height: input.height, samples: result }
}
