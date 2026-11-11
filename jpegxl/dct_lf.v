// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

fn (transform HfTransform) is_dct() bool {
	return transform in [HfTransform.dct, .dct16x16, .dct32x32, .dct16x8, .dct8x16,
		.dct32x8, .dct8x32, .dct32x16, .dct16x32, .dct64x64, .dct64x32, .dct32x64,
		.dct128x128, .dct128x64, .dct64x128, .dct256x256, .dct256x128, .dct128x256]
}

// Replace all low-frequency positions in an owned coefficient vector. LF input
// uses spatial block order; output uses the source's longest-side-first table.
pub fn inject_dct_lf(transform HfTransform, lf []f32, coefficients []f32) ![]f32 {
	blocks := transform.covered_blocks()
	rows := blocks[1]
	columns := blocks[0]
	if !transform.is_dct() || lf.len != rows * columns || coefficients.len != rows * columns * 64 {
		return error('Invalid JPEG XL DCT LF geometry')
	}
	if !all_finite(lf) { return error('Nonfinite JPEG XL DCT LF input') }
	if !all_finite(coefficients) { return error('Nonfinite JPEG XL DCT HF input') }
	// Original dispatch uses ScalarDescriptor whenever either LF axis is < 4.
	fused := rows >= 4 && columns >= 4
	mut low := []f32{len: lf.len}
	if rows >= columns {
		for x in 0 .. columns {
			mut vector := []f32{len: rows}
			for y in 0 .. rows { vector[y] = lf[y * columns + x] }
			values := reinterpreting_dct_vector(vector, fused)!
			for y in 0 .. rows { low[x * rows + y] = values[y] }
		}
		for x in 0 .. rows {
			mut vector := []f32{len: columns}
			for y in 0 .. columns { vector[y] = low[y * rows + x] }
			values := reinterpreting_dct_vector(vector, fused)!
			for y in 0 .. columns { low[y * rows + x] = values[y] }
		}
	} else {
		for y in 0 .. rows {
			values := reinterpreting_dct_vector(lf[y * columns..(y + 1) * columns], fused)!
			for x in 0 .. columns { low[y * columns + x] = values[x] }
		}
		for x in 0 .. columns {
			mut vector := []f32{len: rows}
			for y in 0 .. rows { vector[y] = low[y * columns + x] }
			values := reinterpreting_dct_vector(vector, fused)!
			for y in 0 .. rows { low[y * columns + x] = values[y] }
		}
	}
	longest := if rows > columns { rows } else { columns }
	shortest := if rows < columns { rows } else { columns }
	mut output := coefficients.clone()
	for y in 0 .. shortest {
		for x in 0 .. longest { output[y * longest * 8 + x] = low[y * longest + x] }
	}
	return output
}
