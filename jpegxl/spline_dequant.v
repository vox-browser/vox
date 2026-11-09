// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

pub struct Spline {
pub:
	control_points         []SplinePoint
	color_dct              [3][32]f32
	sigma_dct              [32]f32
	estimated_area_reached u64
}

fn validate_spline_position(x i64, y i64) ! {
	if x < -8388608 || x >= 8388608 || y < -8388608 || y >= 8388608 {
		return error('JPEG XL spline position exceeds its coordinate range')
	}
}

fn spline_adjusted_quant(adjustment i32) f32 {
	shift := f32(0.125) * f32(adjustment)
	if adjustment >= 0 { return f32(1) / (f32(1) + shift) }
	return f32(1) - shift
}

// Rust's release i32::abs wraps MIN, and float-to-u64 conversions saturate.
// Spell these out so C signed overflow or out-of-range casts are unnecessary.
fn spline_coefficient_magnitude(value i32) f32 {
	if value == i32(-2147483647 - 1) { return f32(value) }
	return f32(if value < 0 { -i64(value) } else { i64(value) })
}

fn spline_saturating_u64(value f32) u64 {
	if !(value > 0) { return 0 }
	if value >= f32(18446744073709551616.0) { return u64(0xffffffffffffffff) }
	return u64(value)
}

fn spline_color_log(value u64) u64 {
	// The source's release floor_log2(0) wraps to U64_MAX. This case only
	// occurs when its preceding color + 1 wraps, and is retained explicitly.
	if value == 0 { return u64(0xffffffffffffffff) }
	mut remaining := value - 1
	mut bits := u64(0)
	for remaining != 0 {
		bits++
		remaining >>= 1
	}
	return if bits < 1 { 1 } else { bits }
}

pub fn (quantized QuantizedSpline) dequantize(start SplinePoint, adjustment i32, y_to_x f32, y_to_b f32, area_limit u64) !Spline {
	if quantized.control_points.len > 1048576 || !math.is_finite(start.x) || !math.is_finite(start.y)
		|| !math.is_finite(y_to_x) || !math.is_finite(y_to_b) {
		return error('Invalid JPEG XL spline dequantization context')
	}
	px := math.round(f64(start.x))
	py := math.round(f64(start.y))
	if px < -8388608 || px >= 8388608 || py < -8388608 || py >= 8388608 {
		return error('JPEG XL spline start exceeds its coordinate range')
	}
	mut x := i64(px)
	mut y := i64(py)
	mut points := []SplinePoint{cap: quantized.control_points.len + 1}
	points << SplinePoint{ x: f32(x), y: f32(y) }
	mut dx := i64(0)
	mut dy := i64(0)
	mut distance := u64(0)
	for delta in quantized.control_points {
		if delta.x < -2147483648 || delta.x > 2147483647 || delta.y < -2147483648 || delta.y > 2147483647 {
			return error('JPEG XL spline second difference exceeds the integer range')
		}
		dx += delta.x
		dy += delta.y
		validate_spline_position(dx, dy)!
		distance += u64(if dx < 0 { -dx } else { dx }) + u64(if dy < 0 { -dy } else { dy })
		if distance > area_limit { return error('JPEG XL spline distance exceeds its area limit') }
		x += dx
		y += dy
		validate_spline_position(x, y)!
		points << SplinePoint{ x: f32(x), y: f32(y) }
	}
	inv_quant := spline_adjusted_quant(adjustment)
	weights := [f32(0.0042), 0.075, 0.07, 0.3333]
	mut color := [3][32]f32{}
	mut sigma := [32]f32{}
	for c in 0 .. 3 {
		for i in 0 .. 32 {
			factor := if i == 0 { math.f32_from_bits(0x3f3504f3) } else { f32(1) }
			coefficient := f32(quantized.color_dct[c][i]) * factor
			weighted := coefficient * weights[c]
			color[c][i] = weighted * inv_quant
		}
	}
	for i in 0 .. 32 {
		red := y_to_x * color[1][i]
		blue := y_to_b * color[1][i]
		color[0][i] += red
		color[2][i] += blue
	}
	mut magnitude := [3]u64{}
	for c in 0 .. 3 {
		for i in 0 .. 32 {
			value := inv_quant * spline_coefficient_magnitude(quantized.color_dct[c][i])
			magnitude[c] += spline_saturating_u64(f32(math.ceil(f64(value))))
		}
	}
	magnitude[0] += spline_saturating_u64(f32(math.ceil(f64(math.abs(y_to_x))))) * magnitude[1]
	magnitude[2] += spline_saturating_u64(f32(math.ceil(f64(math.abs(y_to_b))))) * magnitude[1]
	mut maximum := magnitude[0]
	for value in magnitude { if value > maximum { maximum = value } }
	log_color := spline_color_log(maximum + 1)
	max_distance := if distance < 1 { u64(1) } else { distance }
	area_per_color := f32(area_limit) / f32(log_color)
	area_per_distance := area_per_color / f32(max_distance)
	weight_limit := f32(math.ceil(f64(math.sqrtf(area_per_distance))))
	mut width_estimate := u64(0)
	for i in 0 .. 32 {
		factor := if i == 0 { math.f32_from_bits(0x3f3504f3) } else { f32(1) }
		coefficient := f32(quantized.sigma_dct[i]) * factor
		weighted := coefficient * weights[3]
		sigma[i] = weighted * inv_quant
		value := inv_quant * spline_coefficient_magnitude(quantized.sigma_dct[i])
		weight_f := f32(math.ceil(f64(value)))
		at_least_one := if weight_f < 1 { f32(1) } else { weight_f }
		weight := spline_saturating_u64(if weight_limit < at_least_one {
			weight_limit
		} else {
			at_least_one
		})
		width_estimate += weight * weight * log_color
	}
	return Spline{
		control_points:         points
		color_dct:              color
		sigma_dct:              sigma
		estimated_area_reached: width_estimate * distance
	}
}

pub fn (spline Spline) validate_adjacent_points() ! {
	for i in 1 .. spline.control_points.len {
		previous := spline.control_points[i - 1]
		point := spline.control_points[i]
		if math.abs(previous.x - point.x) < f32(0.001) && math.abs(previous.y - point.y) < f32(0.001) {
			return error('JPEG XL spline has coincident adjacent control points')
		}
	}
}
