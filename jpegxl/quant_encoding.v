// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

pub struct LibraryQuantEncoding {}

pub struct IdentityQuantEncoding {
pub:
	weights [3][]f32
}

pub struct Dct2QuantEncoding {
pub:
	weights [3][]f32
}

pub struct Dct4QuantEncoding {
pub:
	parameters  DctQuantWeightParams
	multipliers [3][]f32
}

pub struct Dct4x8QuantEncoding {
pub:
	parameters  DctQuantWeightParams
	multipliers [3][]f32
}

pub struct AfvQuantEncoding {
pub:
	parameters4x8 DctQuantWeightParams
	parameters4x4 DctQuantWeightParams
	weights       [3][]f32
}

pub struct DctQuantEncoding {
pub:
	parameters DctQuantWeightParams
}

pub type NonRawQuantEncoding = AfvQuantEncoding
	| Dct2QuantEncoding
	| Dct4QuantEncoding
	| Dct4x8QuantEncoding
	| DctQuantEncoding
	| IdentityQuantEncoding
	| LibraryQuantEncoding

const quant_table_widths = [1, 1, 1, 1, 2, 4, 1, 1, 2, 1, 1, 8, 4, 16, 8, 32, 16]!
const quant_table_heights = [1, 1, 1, 1, 2, 4, 2, 4, 4, 1, 1, 8, 8, 16, 16, 32, 32]!

pub fn quant_table_blocks(index int) ![2]int {
	if index < 0 || index >= quant_table_widths.len {
		return error('Invalid JPEG XL quantization table index')
	}
	return [quant_table_widths[index], quant_table_heights[index]]!
}

fn (mut reader BitReader) read_quant_weight_rows(count int, scaled_prefix int, check_minimum bool) ![3][]f32 {
	mut rows := [3][]f32{}
	for c in 0 .. 3 {
		mut row := []f32{len: count}
		for i in 0 .. count {
			value := reader.read_quantization_half()!
			if check_minimum && math.abs(value) < f32(1e-8) {
				return error('JPEG XL HF quantization factor is too small')
			}
			row[i] = if i < scaled_prefix { value * f32(64) } else { value }
		}
		rows[c] = row
	}
	return rows
}

// Raw mode 7 carries a separate modular stream and remains outside this parser.
// Library mode identifies a cached matrix; matrix generation is a separate stage.
pub fn (mut reader BitReader) read_nonraw_quant_encoding(table_index int) !NonRawQuantEncoding {
	blocks := quant_table_blocks(table_index)!
	mode := reader.read(3)!
	if mode in [u64(1), 2, 3, 4, 5] && blocks[0] * blocks[1] != 1 {
		return error('Invalid JPEG XL quantization encoding for table size')
	}
	match mode {
		0 { return LibraryQuantEncoding{} }
		1 { return IdentityQuantEncoding{ weights: reader.read_quant_weight_rows(3, 3, true)! } }
		2 { return Dct2QuantEncoding{ weights: reader.read_quant_weight_rows(6, 6, true)! } }
		3 {
			multipliers := reader.read_quant_weight_rows(2, 0, true)!
			return Dct4QuantEncoding{ parameters: reader.read_dct_quant_weight_params()!, multipliers: multipliers }
		}
		4 {
			multipliers := reader.read_quant_weight_rows(1, 0, true)!
			return Dct4x8QuantEncoding{ parameters: reader.read_dct_quant_weight_params()!, multipliers: multipliers }
		}
		5 {
			weights := reader.read_quant_weight_rows(9, 6, false)!
			params4x8 := reader.read_dct_quant_weight_params()!
			params4x4 := reader.read_dct_quant_weight_params()!
			return AfvQuantEncoding{ parameters4x8: params4x8, parameters4x4: params4x4, weights: weights }
		}
		6 { return DctQuantEncoding{ parameters: reader.read_dct_quant_weight_params()! } }
		else { return error('JPEG XL raw quantization tables require modular decoding') }
	}
}
