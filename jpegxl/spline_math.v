// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

// Match the source approximations used by the spline DCT and Gaussian splats.
// These are codec operations, not general-purpose trigonometric guarantees.
fn spline_fast_cos(x f32) f32 {
	pi := math.f32_from_bits(0x40490fdb)
	pi2 := pi * f32(2)
	inverse := f32(0.5) / pi
	scaled := x * inverse
	cycles := f32(math.floor(f64(scaled))) * pi2
	reduced := x - cycles
	reflected := pi2 - reduced
	x_pi := if reduced < reflected { reduced } else { reflected }
	above_half := x_pi >= pi / f32(2)
	x_half := if above_half { pi - x_pi } else { x_pi }
	xs := x_half * f32(0.25)
	x2 := xs * xs
	x4 := x2 * x2
	fourth := x4 * f32(0.06960438)
	second := x2 * f32(-0.84087373)
	inner := second + f32(1.68179268)
	approximation := fourth + inner
	square := approximation * approximation
	first := square - math.f32_from_bits(0x3fb504f3)
	first_square := first * first
	second_scale := first_square - f32(1)
	return if above_half { -second_scale } else { second_scale }
}

fn spline_polynomial_step(a f32, b f32, c f32, fused bool) f32 {
	if fused { return fused_f32(a, b, c) }
	product := a * b
	return product + c
}

// NEON's four polynomial steps use FMA; the original scalar descriptor uses
// separate multiplication/addition. The final square/subtraction is unfused
// in both profiles. Copy the sign explicitly, including negative zero.
fn spline_fast_erf(x f32, fused bool) f32 {
	absx := math.f32_from_bits(math.f32_bits(x) & u32(0x7fffffff))
	d1 := spline_polynomial_step(absx, f32(7.77394369e-02), f32(2.05260015e-04), fused)
	d2 := spline_polynomial_step(d1, absx, f32(2.32120216e-01), fused)
	d3 := spline_polynomial_step(d2, absx, f32(2.77820801e-01), fused)
	d4 := spline_polynomial_step(d3, absx, f32(1), fused)
	square := d4 * d4
	inverse := f32(1) / square
	inverse_square := inverse * inverse
	result := f32(1) - inverse_square
	return math.f32_from_bits((math.f32_bits(result) & u32(0x7fffffff)) | (math.f32_bits(x) & u32(0x80000000)))
}
