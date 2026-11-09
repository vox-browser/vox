// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

fn lf_smoothing_sample(input FloatPlane, x int, y int) f32 {
	p := y * input.width + x
	w := input.width
	corner := input.samples[p - w - 1] + input.samples[p - w + 1] + input.samples[p + w - 1] + input.samples[p + w + 1]
	side := input.samples[p - 1] + input.samples[p + 1] + input.samples[p - w] + input.samples[p + w]
	side_weight := f32(0.20345139757231578)
	corner_weight := f32(0.0334829185968739)
	center_weight := f32(1) - f32(4) * (side_weight + corner_weight)
	// Separate operations retain the scalar source's unfused binary32 rounding.
	corner_sum := corner * corner_weight
	side_sum := side * side_weight
	center_sum := input.samples[p] * center_weight
	neighbors := corner_sum + side_sum
	return neighbors + center_sum
}

pub fn adaptive_lf_smoothing(input []FloatPlane, lf_factors [3]f32) ![]FloatPlane {
	if input.len != 3 { return error('JPEG XL LF smoothing requires three planes') }
	for c, plane in input {
		plane.validate()!
		if plane.width != input[0].width || plane.height != input[0].height {
			return error('Incompatible JPEG XL LF smoothing planes')
		}
		if !math.is_finite(lf_factors[c]) || lf_factors[c] <= 0 {
			return error('Invalid JPEG XL LF smoothing quantization factor')
		}
	}
	if u64(input[0].samples.len) * 3 > 67108864 {
		return error('JPEG XL LF smoothing sample limit exceeded')
	}
	mut output := [][]f32{cap: 3}
	for plane in input { output << plane.samples.clone() }
	width := input[0].width
	height := input[0].height
	if width > 2 && height > 2 {
		for y in 1 .. height - 1 {
			for x in 1 .. width - 1 {
				p := y * width + x
				mut gap := f32(0.5)
				mut smoothed := [3]f32{}
				for c in 0 .. 3 {
					smoothed[c] = lf_smoothing_sample(input[c], x, y)
					difference := math.abs((input[c].samples[p] - smoothed[c]) / lf_factors[c])
					if difference > gap { gap = difference }
				}
				four_gap := f32(4) * gap
				factor := math.max(f32(3) - four_gap, f32(0))
				for c in 0 .. 3 {
					difference := smoothed[c] - input[c].samples[p]
					weighted := difference * factor
					output[c][p] = weighted + input[c].samples[p]
				}
			}
		}
	}
	return [FloatPlane{ width: width, height: height, samples: output[0] },
		FloatPlane{ width: width, height: height, samples: output[1] },
		FloatPlane{ width: width, height: height, samples: output[2] }]
}
