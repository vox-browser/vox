// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

// Whole-plane scalar equivalent of the source stage, with its one-pixel border.
// Returns independent samples and preserves source f32 summation/FMA order.
@[direct_array_access]
pub fn gaborish_plane(input FloatPlane, weight1 f32, weight2 f32) !FloatPlane {
	input.validate()!
	total := (f32(1) + weight1 * f32(4)) + weight2 * f32(4)
	if !math.is_finite(weight1) || !math.is_finite(weight2) || !math.is_finite(total) || math.abs(total) < f32(0.000001) {
		return error('Invalid JPEG XL Gaborish weights')
	}
	w0 := f32(1) / total
	w1 := weight1 / total
	w2 := weight2 / total
	mut result := []f32{len: input.samples.len}
	w := input.width
	h := input.height
	src := unsafe { &f32(input.samples.data) }
	dst := unsafe { &f32(result.data) }
	for y in 0 .. h {
		if y == 0 || y == h - 1 || w < 3 {
			for x in 0 .. w { unsafe { dst[y * w + x] = gaborish_border_sample(input, x, y, w0, w1, w2) } }
			continue
		}
		// Interior samples read their neighbours directly, in the same
		// summation order as the clamped border samples.
		unsafe { dst[y * w] = gaborish_border_sample(input, 0, y, w0, w1, w2) }
		for x in 1 .. w - 1 {
			i := y * w + x
			unsafe {
				cross := ((src[i - w] + src[i - 1]) + src[i + w]) + src[i + 1]
				corners := ((src[i - w - 1] + src[i - w + 1]) + src[i + w - 1]) + src[i + w + 1]
				dst[i] = fused_f32(w2, corners, fused_f32(w1, cross, src[i] * w0))
			}
		}
		unsafe { dst[y * w + w - 1] = gaborish_border_sample(input, w - 1, y, w0, w1, w2) }
	}
	return FloatPlane{ width: input.width, height: input.height, samples: result }
}

fn gaborish_border_sample(input FloatPlane, x int, y int, w0 f32, w1 f32, w2 f32) f32 {
	cross := ((input.at_border(x, y - 1) + input.at_border(x - 1, y)) + input.at_border(x, y + 1)) + input.at_border(x + 1, y)
	corners := ((input.at_border(x - 1, y - 1) + input.at_border(x + 1, y - 1)) + input.at_border(x - 1, y + 1)) + input.at_border(x + 1, y + 1)
	return fused_f32(w2, corners, fused_f32(w1, cross, input.samples[y * input.width + x] * w0))
}
