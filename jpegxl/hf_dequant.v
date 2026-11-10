// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

pub struct HfDequantParameters {
pub:
	transform         HfTransform
	storage           ModularStorage
	quantizer         QuantizerParams
	raw_quant         u32
	x_qm_scale        u32
	b_qm_scale        u32
	color_correlation ColorCorrelationParams
	x_color_factor    i32
	b_color_factor    i32
	biases            [4]f32
}

fn adjust_hf_quant_bias(value i32, channel int, biases [4]f32) f32 {
	// SIMD abs wraps at i32::MIN. Preserve its signed comparison with two.
	absolute := if value < 0 { i32(u32(0) - u32(value)) } else { value }
	quantized := f32(value)
	if absolute < 2 { return quantized * biases[channel] }
	correction := biases[3] / quantized
	return quantized - correction
}

// Return three coefficient vectors in the matrix table's flat ordering. Spatial
// placement and replacing the LF coefficients belong to the inverse transform.
@[direct_array_access]
pub fn dequantize_hf_block(coefficients [3][]i32, matrices DequantMatrices, params HfDequantParameters) ![3][]f32 {
	return dequantize_hf_block_into(coefficients, matrices, params, none)
}

// With `buffers`, results are written into their first `num` values (each must
// hold the block's coefficient count) instead of fresh arrays.
// matrix_for_transform checks the table holds 3 * num samples and every
// coefficient channel is checked to hold num values.
@[direct_array_access]
fn dequantize_hf_block_into(coefficients [3][]i32, matrices DequantMatrices, params HfDequantParameters, buffers ?[3][]f32) ![3][]f32 {
	if params.quantizer.global_scale < 1 || params.quantizer.global_scale > 73728 || params.raw_quant == 0 || params.x_qm_scale > 7 || params.b_qm_scale > 7 {
		return error('Invalid JPEG XL HF quantization scale')
	}
	cc := params.color_correlation
	if cc.color_factor < 2 || cc.color_factor > 65793 || !math.is_finite(cc.base_correlation_x) || !math.is_finite(cc.base_correlation_b) || math.abs(cc.base_correlation_x) > f32(4) || math.abs(cc.base_correlation_b) > f32(4) || params.x_color_factor < -128 || params.x_color_factor > 127 || params.b_color_factor < -128 || params.b_color_factor > 127 {
		return error('Invalid JPEG XL HF color correlation')
	}
	for bias in params.biases {
		if !math.is_finite(bias) { return error('Nonfinite JPEG XL quantization bias') }
	}
	table := matrices.matrix_for_transform(params.transform)!
	num := table.rows * table.columns
	for channel in coefficients {
		if channel.len != num { return error('Invalid JPEG XL HF coefficient storage') }
	}
	mut weights_valid := true
	for i in 0 .. table.samples.len {
		weight := table.samples[i]
		if !math.is_finite(weight) || weight <= 0 { weights_valid = false }
	}
	if !weights_valid { return error('Invalid JPEG XL dequantization weight') }
	scaled_y := params.quantizer.inverse_global_scale() / f32(params.raw_quant)
	x_multiplier := math.powf(f32(1) / f32(1.25), f32(params.x_qm_scale) - f32(2))
	b_multiplier := math.powf(f32(1) / f32(1.25), f32(params.b_qm_scale) - f32(2))
	scales := [scaled_y * x_multiplier, scaled_y, scaled_y * b_multiplier]!
	x_cc := cc.y_to_x(params.x_color_factor)
	b_cc := cc.y_to_b(params.b_color_factor)
	mut result := [3][]f32{}
	if supplied := buffers {
		for c in 0 .. 3 {
			if supplied[c].len < num { return error('Invalid JPEG XL dequantization buffer') }
			result[c] = unsafe { supplied[c][..num] }
		}
	} else {
		for c in 0 .. 3 { result[c] = []f32{len: num} }
	}
	dequantize_hf_values(coefficients, table, num, scales, x_cc, b_cc, params, mut result)
	return result
}

@[direct_array_access]
fn dequantize_hf_values(coefficients [3][]i32, table DequantMatrix, num int, scales [3]f32, x_cc f32, b_cc f32, params HfDequantParameters, mut result [3][]f32) {
	for k in 0 .. num {
		mut dequantized := [3]f32{}
		for c in 0 .. 3 {
			multiplier := table.samples[c * num + k] * scales[c]
			value := modular_storage_value(coefficients[c][k], params.storage)
			dequantized[c] = adjust_hf_quant_bias(value, c, params.biases) * multiplier
		}
		result[0][k] = fused_f32(x_cc, dequantized[1], dequantized[0])
		result[1][k] = dequantized[1]
		result[2][k] = fused_f32(b_cc, dequantized[1], dequantized[2])
	}
}
