// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct DequantMatrices {
pub:
	tables []DequantMatrix
}

pub fn (mut reader BitReader) read_dequant_matrices(frame FrameHeader, storage ModularStorage, global_tree ?ModularTree) !DequantMatrices {
	all_default := reader.read(1)! != 0
	mut tables := []DequantMatrix{cap: 17}
	for index in 0 .. 17 {
		tables << if all_default {
			compute_quant_matrix(LibraryQuantEncoding{}, index)!
		} else {
			reader.read_quant_matrix(index, frame, storage, global_tree)!
		}
	}
	return DequantMatrices{ tables: tables }
}

fn (matrices DequantMatrices) matrix_for_transform(transform HfTransform) !DequantMatrix {
	if matrices.tables.len != 17 { return error('Incomplete JPEG XL quantization matrix set') }
	index := transform.quant_table_index()
	blocks := quant_table_blocks(index)!
	table := matrices.tables[index]
	if table.rows != blocks[0] * 8 || table.columns != blocks[1] * 8 || table.samples.len != 3 * blocks[0] * blocks[1] * 64 {
		return error('Invalid JPEG XL quantization matrix geometry')
	}
	return table
}

// Return an owned channel so callers cannot modify the stored immutable tables.
pub fn (matrices DequantMatrices) channel(transform HfTransform, channel int) ![]f32 {
	if channel < 0 || channel >= 3 { return error('Invalid JPEG XL quantization matrix channel') }
	table := matrices.matrix_for_transform(transform)!
	num := table.rows * table.columns
	return table.samples[channel * num..(channel + 1) * num].clone()
}
