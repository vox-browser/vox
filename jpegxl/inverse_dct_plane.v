// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

// The source stores each coefficient matrix with its longest side contiguous.
// Rows/columns describe the spatial output, including its transpose convention.
pub fn inverse_dct_plane(rows int, columns int, coefficients []f32) !FloatPlane {
	valid := match rows {
		2 { columns == 2 }
		4 { columns == 4 || columns == 8 }
		8 { columns == 4 || columns == 8 || columns == 16 || columns == 32 }
		16 { columns == 8 || columns == 16 || columns == 32 }
		32 { columns == 8 || columns == 16 || columns == 32 || columns == 64 }
		64 { columns == 32 || columns == 64 || columns == 128 }
		128 { columns == 64 || columns == 128 || columns == 256 }
		256 { columns == 128 || columns == 256 }
		else { false }
	}
	if !valid || coefficients.len != rows * columns {
		return error('Invalid JPEG XL inverse DCT plane geometry')
	}
	for value in coefficients {
		if !math.is_finite(value) { return error('Nonfinite JPEG XL DCT coefficient') }
	}
	mut output := []f32{len: coefficients.len}
	if rows >= columns {
		// Transform the short vertical axis, transpose, then the long axis.
		for x in 0 .. rows {
			mut vector := []f32{len: columns}
			for y in 0 .. columns { vector[y] = coefficients[y * rows + x] }
			values := inverse_dct_values(vector)!
			for y in 0 .. columns { output[x * columns + y] = values[y] }
		}
		for x in 0 .. columns {
			mut vector := []f32{len: rows}
			for y in 0 .. rows { vector[y] = output[y * columns + x] }
			values := inverse_dct_values(vector)!
			for y in 0 .. rows { output[y * columns + x] = values[y] }
		}
	} else {
		// Wide output transforms rows before columns, without a final transpose.
		for y in 0 .. rows {
			values := inverse_dct_values(coefficients[y * columns..(y + 1) * columns])!
			for x in 0 .. columns { output[y * columns + x] = values[x] }
		}
		for x in 0 .. columns {
			mut vector := []f32{len: rows}
			for y in 0 .. rows { vector[y] = output[y * columns + x] }
			values := inverse_dct_values(vector)!
			for y in 0 .. rows { output[y * columns + x] = values[y] }
		}
	}
	return FloatPlane{ width: columns, height: rows, samples: output }
}
