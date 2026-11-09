// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct SplinePoint {
pub:
	x f32
	y f32
}

pub struct SplineDelta {
pub:
	x i64
	y i64
}

pub struct QuantizedSpline {
pub:
	control_points []SplineDelta
	color_dct      [3][32]i32
	sigma_dct      [32]i32
}

pub struct Splines {
pub:
	quantization_adjustment i32
	splines                 []QuantizedSpline
	starting_points         []SplinePoint
}

// Decode quantized state only. Curves, Gaussian splats and their draw cache
// are separate from this entropy stream and are not initialized here.
pub fn (mut reader BitReader) read_splines(num_pixels u32) !Splines {
	hist := reader.read_histograms(6, true)!
	mut symbols := SymbolReader.new(hist, mut reader, none)!
	count := u64(symbols.read_unsigned(hist, 2, mut reader)!) + 1
	maximum := if num_pixels / 2 < 1048576 { num_pixels / 2 } else { u32(1048576) }
	if count > maximum { return error('Too many JPEG XL splines') }
	mut starting_points := []SplinePoint{cap: int(count)}
	mut last_x := i64(0)
	mut last_y := i64(0)
	for i in 0 .. int(count) {
		x := symbols.read_unsigned(hist, 1, mut reader)!
		y := symbols.read_unsigned(hist, 1, mut reader)!
		last_x = if i == 0 { i64(x) } else { last_x + i64(unpack_signed(x)) }
		last_y = if i == 0 { i64(y) } else { last_y + i64(unpack_signed(y)) }
		if last_x <= -8388608 || last_x >= 8388608 || last_y <= -8388608 || last_y >= 8388608 {
			return error('JPEG XL spline starting point exceeds the coordinate limit')
		}
		starting_points << SplinePoint{ x: f32(last_x), y: f32(last_y) }
	}
	adjustment := symbols.read_signed(hist, 0, mut reader)!
	mut splines := []QuantizedSpline{cap: int(count)}
	mut total := u32(0)
	for _ in 0 .. int(count) {
		spline := read_quantized_spline(hist, mut symbols, mut reader, maximum - total)!
		total += u32(spline.control_points.len)
		splines << spline
	}
	symbols.check_final_state(hist, reader)!
	return Splines{
		quantization_adjustment: adjustment
		splines:                 splines
		starting_points:         starting_points
	}
}

fn read_quantized_spline(hist Histograms, mut symbols SymbolReader, mut reader BitReader, remaining u32) !QuantizedSpline {
	count := symbols.read_unsigned(hist, 3, mut reader)!
	// Check against the remaining budget before reserving. This also rejects
	// malformed counts that could wrap the source's u32 accumulated total.
	if count > remaining {
		return error('Too many JPEG XL spline control points')
	}
	mut points := []SplineDelta{cap: int(count)}
	for _ in 0 .. int(count) {
		x := i64(symbols.read_signed(hist, 4, mut reader)!)
		y := i64(symbols.read_signed(hist, 4, mut reader)!)
		if x <= -1073741824 || x >= 1073741824 || y <= -1073741824 || y >= 1073741824 {
			return error('JPEG XL spline second difference exceeds the delta limit')
		}
		points << SplineDelta{ x: x, y: y }
	}
	mut color_dct := [3][32]i32{}
	mut sigma_dct := [32]i32{}
	for c in 0 .. 3 {
		for i in 0 .. 32 {
			color_dct[c][i] = symbols.read_signed(hist, 5, mut reader)!
		}
	}
	for i in 0 .. 32 { sigma_dct[i] = symbols.read_signed(hist, 5, mut reader)! }
	return QuantizedSpline{ control_points: points, color_dct: color_dct, sigma_dct: sigma_dct }
}
