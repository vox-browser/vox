// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

// LF inputs are in the transform's covered-block order; coefficients retain the
// dequantization table order. Neither input is modified.
pub fn inverse_hf_transform(transform HfTransform, lf []f32, coefficients []f32) !FloatPlane {
	blocks := transform.covered_blocks()
	if lf.len != blocks[0] * blocks[1] || coefficients.len != lf.len * 64 {
		return error('Invalid JPEG XL inverse transform storage')
	}
	for value in lf {
		if !math.is_finite(value) { return error('Nonfinite JPEG XL LF coefficient') }
	}
	for value in coefficients {
		if !math.is_finite(value) { return error('Nonfinite JPEG XL HF coefficient') }
	}
	mut output := coefficients.clone()
	output[0] = lf[0]
	match transform {
		.identity { inverse_identity(mut output) }
		else { return error('Unsupported JPEG XL inverse transform') }
	}
	return FloatPlane{ width: blocks[0] * 8, height: blocks[1] * 8, samples: output }
}

fn inverse_identity(mut output []f32) {
	coefficients := output.clone()
	b00 := coefficients[0]
	b01 := coefficients[1]
	b10 := coefficients[8]
	b11 := coefficients[9]
	dcs := [b00 + b01 + b10 + b11, b00 + b01 - b10 - b11,
		b00 - b01 + b10 - b11, b00 - b01 - b10 + b11]!
	for y in 0 .. 2 {
		for x in 0 .. 2 {
			mut residual_sum := f32(0)
			for iy in 0 .. 4 {
				for ix in 0 .. 4 {
					if ix == 0 && iy == 0 { continue }
					residual_sum += coefficients[(y + iy * 2) * 8 + x + ix * 2]
				}
			}
			residual := residual_sum * f32(1.0 / 16.0)
			center := dcs[y * 2 + x] - residual
			output[(4 * y + 1) * 8 + 4 * x + 1] = center
			for iy in 0 .. 4 {
				for ix in 0 .. 4 {
					if ix == 1 && iy == 1 { continue }
					output[(y * 4 + iy) * 8 + x * 4 + ix] = coefficients[(y + iy * 2) * 8 + x + ix * 2] + center
				}
			}
			output[y * 4 * 8 + x * 4] = coefficients[(y + 2) * 8 + x + 2] + center
		}
	}
}
