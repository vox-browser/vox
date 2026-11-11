// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

// The pinned source uses BF16 lookup on NEON/SSE, and full precision on AVX
// and scalar paths. Keep this choice explicit for deterministic output.
pub enum NoiseLutPrecision {
	full
	bfloat16
}

fn noise_strength(value f32, lut [8]f32) f32 {
	scaled := math.max(value * f32(6), f32(0))
	pre_floor := f32(math.floor(scaled))
	fraction := if pre_floor > f32(6) { f32(1) } else { scaled - pre_floor }
	index := int(math.min(pre_floor, f32(6)))
	low := lut[index]
	high := lut[index + 1]
	return math.min(math.max(fused_f32(high - low, fraction, low), f32(0)), f32(1))
}

// Apply convolved random planes in source color space, before color conversion.
// Input/color buffers remain unchanged. Random-field generation is separate.
pub fn add_noise_planes(input [3]FloatPlane, random [3]FloatPlane, noise NoiseParams, correlation ColorCorrelationParams, precision NoiseLutPrecision) ![3]FloatPlane {
	if u64(input[0].samples.len) * 3 > 67108864 { return error('JPEG XL noise output sample budget exceeded') }
	for c in 0 .. 3 {
		for plane in [input[c], random[c]] {
			plane.validate()!
			if plane.width != input[0].width || plane.height != input[0].height
				|| !all_finite(plane.samples) { return error('Invalid JPEG XL noise plane geometry or samples') }
		}
	}
	for value in noise.lut { if !math.is_finite(value) { return error('Nonfinite JPEG XL noise LUT') } }
	if correlation.color_factor == 0 || !math.is_finite(correlation.base_correlation_x) || !math.is_finite(correlation.base_correlation_b) {
		return error('Invalid JPEG XL noise color correlation')
	}
	if noise.lut == [8]f32{} { return input }
	mut lut := noise.lut
	if precision == .bfloat16 { for i in 0 .. 8 { lut[i] = math.f32_from_bits(math.f32_bits(lut[i]) & u32(0xffff0000)) } }
	ytox := correlation.y_to_x_lf()
	ytob := correlation.y_to_b_lf()
	mut samples := [3][]f32{}
	for c in 0 .. 3 { samples[c] = input[c].samples.clone() }
	for i in 0 .. input[0].samples.len {
		vx := input[0].samples[i]
		vy := input[1].samples[i]
		vb := input[2].samples[i]
		green_strength := noise_strength((vy - vx) * f32(0.5), lut)
		red_strength := noise_strength((vy + vx) * f32(0.5), lut)
		rnd_r := random[0].samples[i] * f32(0.22)
		rnd_g := random[1].samples[i] * f32(0.22)
		rnd_c := random[2].samples[i] * f32(0.22)
		common := rnd_c * f32(0.9921875)
		red := red_strength * fused_f32(rnd_r, f32(0.0078125), common)
		green := green_strength * fused_f32(rnd_g, f32(0.0078125), common)
		rg := red + green
		samples[0][i] = vx + fused_f32(rg, ytox, red - green)
		samples[1][i] = vy + rg
		// Separate expressions preserve the source's unfused B operation;
		// a single C expression would permit contraction into one rounding.
		blue := rg * ytob
		samples[2][i] = vb + blue
	}
	mut output := [3]FloatPlane{}
	for c in 0 .. 3 { output[c] = FloatPlane{ width: input[c].width, height: input[c].height, samples: samples[c] } }
	return output
}
