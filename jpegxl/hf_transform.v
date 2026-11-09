// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

// Serialized VarDCT transform IDs follow jxl_transforms::HfTransformType.
pub enum HfTransform {
	dct
	identity
	dct2x2
	dct4x4
	dct16x16
	dct32x32
	dct16x8
	dct8x16
	dct32x8
	dct8x32
	dct32x16
	dct16x32
	dct4x8
	dct8x4
	afv0
	afv1
	afv2
	afv3
	dct64x64
	dct64x32
	dct32x64
	dct128x128
	dct128x64
	dct64x128
	dct256x256
	dct256x128
	dct128x256
}

const hf_transform_widths = [1, 1, 1, 1, 2, 4, 1, 2, 1, 4, 2, 4, 1, 1, 1, 1, 1, 1, 8, 4, 8, 16,
	8, 16, 32, 16, 32]!
const hf_transform_heights = [1, 1, 1, 1, 2, 4, 2, 1, 4, 1, 4, 2, 1, 1, 1, 1, 1, 1, 8, 8, 4, 16,
	16, 8, 32, 32, 16]!
const hf_transform_shapes = [0, 1, 1, 1, 2, 3, 4, 4, 5, 5, 6, 6, 1, 1, 1, 1, 1, 1, 7, 8, 8, 9,
	10, 10, 11, 12, 12]!
const hf_transform_quant_tables = [0, 1, 2, 3, 4, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 10, 10, 11,
	12, 12, 13, 14, 14, 15, 16, 16]!

pub fn hf_transform_from_id(id int) !HfTransform {
	if id < 0 || id >= hf_transform_widths.len {
		return error('Invalid JPEG XL VarDCT transform')
	}
	return unsafe { HfTransform(id) }
}

pub fn (transform HfTransform) covered_blocks() [2]int {
	return [hf_transform_widths[int(transform)], hf_transform_heights[int(transform)]]!
}

pub fn (transform HfTransform) shape_id() int {
	return hf_transform_shapes[int(transform)]
}

pub fn (transform HfTransform) quant_table_index() int {
	return hf_transform_quant_tables[int(transform)]
}
