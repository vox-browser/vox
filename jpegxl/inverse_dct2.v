// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

fn idct2_top_block(size int, input []f32, mut output []f32) {
	num := size / 2
	for y in 0 .. num {
		for x in 0 .. num {
			c00 := input[y * 8 + x]
			c01 := input[y * 8 + num + x]
			c10 := input[(y + num) * 8 + x]
			c11 := input[(y + num) * 8 + num + x]
			output[y * 2 * 8 + x * 2] = c00 + c01 + c10 + c11
			output[y * 2 * 8 + x * 2 + 1] = c00 + c01 - c10 - c11
			output[(y * 2 + 1) * 8 + x * 2] = c00 - c01 + c10 - c11
			output[(y * 2 + 1) * 8 + x * 2 + 1] = c00 - c01 - c10 + c11
		}
	}
}

fn inverse_dct2x2(mut output []f32) {
	mut temporary := output.clone()
	idct2_top_block(2, temporary, mut output)
	idct2_top_block(4, output, mut temporary)
	idct2_top_block(8, temporary, mut output)
}
