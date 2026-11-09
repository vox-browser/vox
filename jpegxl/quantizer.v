// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct QuantizerParams {
pub:
	global_scale u32
	quant_lf     u32
}

pub fn (mut reader BitReader) read_quantizer_params() !QuantizerParams {
	global_scale := reader.read_u32([U32Code{ bits: 11, offset: 1 }, U32Code{ bits: 11, offset: 2049 },
		U32Code{ bits: 12, offset: 4097 }, U32Code{ bits: 16, offset: 8193 }]!)!
	quant_lf := reader.read_u32([U32Code{ offset: 16 }, U32Code{ bits: 5, offset: 1 },
		U32Code{ bits: 8, offset: 1 }, U32Code{ bits: 16, offset: 1 }]!)!
	return QuantizerParams{ global_scale: global_scale, quant_lf: quant_lf }
}

pub fn (params QuantizerParams) inverse_global_scale() f32 {
	return f32(65536) / f32(params.global_scale)
}

pub fn (params QuantizerParams) inverse_quant_lf() f32 {
	return params.inverse_global_scale() / f32(params.quant_lf)
}
