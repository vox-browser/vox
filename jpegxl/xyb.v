// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

struct XybParameters {
	matrix          [9]f32
	bias_cbrt       [3]f32
	scaled_bias     [3]f32
	intensity_scale f32
}

fn xyb_parameters(opsin OpsinInverseMatrix, intensity_target f32) !XybParameters {
	if !math.is_finite(intensity_target) || intensity_target <= 0 {
		return error('Invalid JPEG XL XYB intensity target')
	}
	for value in opsin.inverse_matrix { if !math.is_finite(value) { return error('Nonfinite JPEG XL opsin matrix') } }
	mut roots := [3]f32{}
	mut scaled := [3]f32{}
	scale := f32(255) / intensity_target
	for c in 0 .. 3 {
		bias := opsin.opsin_biases[c]
		if !math.is_finite(bias) { return error('Nonfinite JPEG XL opsin bias') }
		roots[c] = f32(math.cbrt(f64(bias)))
		scaled[c] = bias * scale
	}
	return XybParameters{ matrix: opsin.inverse_matrix, bias_cbrt: roots, scaled_bias: scaled, intensity_scale: scale }
}

// Output is linear RGB in the supplied inverse matrix's primaries. Selecting
// an output color profile and applying its transfer curve are separate stages.
pub fn xyb_to_linear(input [3]FloatPlane, opsin OpsinInverseMatrix, intensity_target f32) ![3]FloatPlane {
	params := xyb_parameters(opsin, intensity_target)!
	for plane in input {
		plane.validate()!
		if plane.width != input[0].width || plane.height != input[0].height {
			return error('Incompatible JPEG XL XYB plane geometry')
		}
		for value in plane.samples { if !math.is_finite(value) { return error('Nonfinite JPEG XL XYB sample') } }
	}
	mut samples := [3][]f32{}
	for c in 0 .. 3 { samples[c] = []f32{len: input[c].samples.len} }
	for i in 0 .. input[0].samples.len {
		x := input[0].samples[i]
		y := input[1].samples[i]
		b := input[2].samples[i]
		l := y + x - params.bias_cbrt[0]
		m := y - x - params.bias_cbrt[1]
		s := b - params.bias_cbrt[2]
		l2 := l * l
		m2 := m * m
		s2 := s * s
		scaled_l := l * params.intensity_scale
		scaled_m := m * params.intensity_scale
		scaled_s := s * params.intensity_scale
		linear_l := fused_f32(l2, scaled_l, params.scaled_bias[0])
		linear_m := fused_f32(m2, scaled_m, params.scaled_bias[1])
		linear_s := fused_f32(s2, scaled_s, params.scaled_bias[2])
		for c in 0 .. 3 {
			row := c * 3
			samples[c][i] = fused_f32(params.matrix[row], linear_l,
				fused_f32(params.matrix[row + 1], linear_m, params.matrix[row + 2] * linear_s))
		}
	}
	mut result := [3]FloatPlane{}
	for c in 0 .. 3 { result[c] = FloatPlane{ width: input[c].width, height: input[c].height, samples: samples[c] } }
	return result
}
