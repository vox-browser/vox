// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

fn inverse_dct4x4_blocks(mut output []f32) ! {
	coefficients := output.clone()
	b00 := coefficients[0]
	b01 := coefficients[1]
	b10 := coefficients[8]
	b11 := coefficients[9]
	dcs := [b00 + b01 + b10 + b11, b00 + b01 - b10 - b11,
		b00 - b01 + b10 - b11, b00 - b01 - b10 + b11]!
	for y in 0 .. 2 {
		for x in 0 .. 2 {
			mut block := []f32{len: 16}
			block[0] = dcs[y * 2 + x]
			for iy in 0 .. 4 {
				for ix in 0 .. 4 {
					if ix == 0 && iy == 0 { continue }
					block[iy * 4 + ix] = coefficients[(y + iy * 2) * 8 + x + ix * 2]
				}
			}
			plane := inverse_dct_plane(4, 4, block)!
			for iy in 0 .. 4 {
				for ix in 0 .. 4 {
					output[(y * 4 + iy) * 8 + x * 4 + ix] = plane.samples[iy * 4 + ix]
				}
			}
		}
	}
}

fn inverse_rectangular_dct_blocks(transform HfTransform, mut output []f32) ! {
	coefficients := output.clone()
	dcs := [coefficients[0] + coefficients[8], coefficients[0] - coefficients[8]]!
	vertical := transform == .dct8x4
	rows := if vertical { 8 } else { 4 }
	columns := if vertical { 4 } else { 8 }
	for part in 0 .. 2 {
		mut block := []f32{len: 32}
		for iy in 0 .. 4 {
			for ix in 0 .. 8 {
				block[iy * 8 + ix] = if ix == 0 && iy == 0 {
					dcs[part]
				} else {
					coefficients[(part + iy * 2) * 8 + ix]
				}
			}
		}
		plane := inverse_dct_plane(rows, columns, block)!
		for y in 0 .. rows {
			for x in 0 .. columns {
				destination := if vertical { y * 8 + part * 4 + x } else { (part * 4 + y) * 8 + x }
				output[destination] = plane.samples[y * columns + x]
			}
		}
	}
}
