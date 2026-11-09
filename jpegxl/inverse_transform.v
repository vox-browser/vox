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
		.dct { return inverse_dct_plane(8, 8, output) }
		.dct16x16, .dct32x32, .dct16x8, .dct8x16, .dct32x8, .dct8x32, .dct32x16, .dct16x32,
		.dct64x64, .dct64x32, .dct32x64, .dct128x128, .dct128x64, .dct64x128,
		.dct256x256, .dct256x128, .dct128x256 {
			injected := inject_dct_lf(transform, lf, coefficients)!
			return inverse_dct_plane(blocks[1] * 8, blocks[0] * 8, injected)
		}
		.dct4x4 { inverse_dct4x4_blocks(mut output)! }
		.dct4x8, .dct8x4 { inverse_rectangular_dct_blocks(transform, mut output)! }
		.identity { inverse_identity(mut output) }
		.dct2x2 { inverse_dct2x2(mut output) }
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
