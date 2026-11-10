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
	for y in 0 .. input.height {
		interior_row := y > 0 && y < input.height - 1
		for x in 0 .. w {
			i := y * w + x
			// Interior samples read their neighbours directly; borders clamp.
			// Both keep the same summation order.
			mut cross := f32(0)
			mut corners := f32(0)
			if interior_row && x > 0 && x < w - 1 {
				cross = ((input.samples[i - w] + input.samples[i - 1]) + input.samples[i + w]) + input.samples[i + 1]
				corners = ((input.samples[i - w - 1] + input.samples[i - w + 1]) + input.samples[i + w - 1]) + input.samples[i + w + 1]
			} else {
				cross = ((input.at_border(x, y - 1) + input.at_border(x - 1, y)) + input.at_border(x, y + 1)) + input.at_border(x + 1, y)
				corners = ((input.at_border(x - 1, y - 1) + input.at_border(x + 1, y - 1)) + input.at_border(x - 1, y + 1)) + input.at_border(x + 1, y + 1)
			}
			center := input.samples[i] * w0
			result[i] = fused_f32(w2, corners, fused_f32(w1, cross, center))
		}
	}
	return FloatPlane{ width: input.width, height: input.height, samples: result }
}
