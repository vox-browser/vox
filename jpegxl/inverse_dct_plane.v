// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

// The source stores each coefficient matrix with its longest side contiguous.
// Rows/columns describe the spatial output, including its transpose convention.
@[direct_array_access]
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
	if !all_finite(coefficients) { return error('Nonfinite JPEG XL DCT coefficient') }
	mut output := []f32{len: coefficients.len}
	mut vector := []f32{len: if rows > columns { rows } else { columns }}
	inverse_dct_plane_into(rows, columns, coefficients, mut output, mut vector)!
	return FloatPlane{ width: columns, height: rows, samples: output }
}

// inverse_dct_plane into caller buffers. `output` must not alias the
// coefficients; `vector` is scratch for one row or column.
@[direct_array_access]
fn inverse_dct_plane_into(rows int, columns int, coefficients []f32, mut output []f32, mut vector []f32) ! {
	if rows <= 0 || columns <= 0 || coefficients.len != rows * columns || output.len < rows * columns
		|| vector.len < rows || vector.len < columns {
		return error('Invalid JPEG XL inverse DCT buffers')
	}
	if rows >= columns {
		// Transform the short vertical axis, transpose, then the long axis.
		for x in 0 .. rows {
			for y in 0 .. columns { vector[y] = coefficients[y * rows + x] }
			inverse_dct_in_place(mut vector, columns)!
			for y in 0 .. columns { output[x * columns + y] = vector[y] }
		}
		for x in 0 .. columns {
			for y in 0 .. rows { vector[y] = output[y * columns + x] }
			inverse_dct_in_place(mut vector, rows)!
			for y in 0 .. rows { output[y * columns + x] = vector[y] }
		}
	} else {
		// Wide output transforms rows before columns, without a final transpose.
		for y in 0 .. rows {
			for x in 0 .. columns { vector[x] = coefficients[y * columns + x] }
			inverse_dct_in_place(mut vector, columns)!
			for x in 0 .. columns { output[y * columns + x] = vector[x] }
		}
		for x in 0 .. columns {
			for y in 0 .. rows { vector[y] = output[y * columns + x] }
			inverse_dct_in_place(mut vector, rows)!
			for y in 0 .. rows { output[y * columns + x] = vector[y] }
		}
	}
}
