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
	return dequantize_hf_block_into(coefficients, matrices, params, none, false)
}

// With `buffers`, results are written into their first `num` values (each must
// hold the block's coefficient count) instead of fresh arrays. `weights_checked`
// skips validating the transform's table weights, which a caller rendering
// many blocks with the same immutable tables has already done.
// matrix_for_transform checks the table holds 3 * num samples and every
// coefficient channel is checked to hold num values.
@[direct_array_access]
fn dequantize_hf_block_into(coefficients [3][]i32, matrices DequantMatrices, params HfDequantParameters, buffers ?[3][]f32, weights_checked bool) ![3][]f32 {
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
	if !weights_checked {
		mut weights_valid := true
		for i in 0 .. table.samples.len {
			weight := table.samples[i]
			if !math.is_finite(weight) || weight <= 0 { weights_valid = false }
		}
		if !weights_valid { return error('Invalid JPEG XL dequantization weight') }
	}
	scaled_y := params.quantizer.inverse_global_scale() / f32(params.raw_quant)
	x_multiplier := hf_qm_multipliers[params.x_qm_scale]
	b_multiplier := hf_qm_multipliers[params.b_qm_scale]
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

// pow(1 / 1.25, scale - 2) for the qm scales 0 ..= 7.
const hf_qm_multipliers = hf_qm_multiplier_table()

fn hf_qm_multiplier_table() [8]f32 {
	mut table := [8]f32{}
	for scale in 0 .. 8 { table[scale] = math.powf(f32(1) / f32(1.25), f32(scale) - f32(2)) }
	return table
}

// adjust_hf_quant_bias without branches, so channel loops vectorize. The wrapping
// absolute value keeps i32::MIN below two, as the signed comparison requires.
@[inline]
fn adjusted_hf_value(value i32, bias f32, bias3 f32) f32 {
	sign := u32(value >> 31)
	absolute := i32((u32(value) ^ sign) - sign)
	quantized := f32(value)
	small := quantized * bias
	large := quantized - bias3 / quantized
	mask := u32(0) - u32(absolute < 2)
	return math.f32_from_bits((math.f32_bits(small) & mask) | (math.f32_bits(large) & ~mask))
}

// One channel of a block: out[k] is coefficient k, read with the storage's
// width and bias-adjusted, times weights[k] * scale.
@[direct_array_access]
fn dequantize_hf_channel(out &f32, coefficients &i32, weights &f32, num int, scale f32, bias f32, bias3 f32, signed16 bool) {
	if signed16 {
		for k in 0 .. num {
			unsafe {
				multiplier := weights[k] * scale
				out[k] = adjusted_hf_value(i32(i16(coefficients[k])), bias, bias3) * multiplier
			}
		}
	} else {
		for k in 0 .. num {
			unsafe {
				multiplier := weights[k] * scale
				out[k] = adjusted_hf_value(coefficients[k], bias, bias3) * multiplier
			}
		}
	}
}

// Channels are dequantized separately, then X and B add their correlation
// with Y, as the source does per coefficient.
@[direct_array_access]
fn dequantize_hf_values(coefficients [3][]i32, table DequantMatrix, num int, scales [3]f32, x_cc f32, b_cc f32, params HfDequantParameters, mut result [3][]f32) {
	signed16 := params.storage == .signed16
	for c in 0 .. 3 {
		dequantize_hf_channel(unsafe { &f32(result[c].data) }, unsafe { &i32(coefficients[c].data) },
			unsafe { &f32(table.samples.data) + c * num }, num, scales[c], params.biases[c], params.biases[3], signed16)
	}
	r0 := unsafe { &f32(result[0].data) }
	r1 := unsafe { &f32(result[1].data) }
	r2 := unsafe { &f32(result[2].data) }
	for k in 0 .. num {
		unsafe {
			y := r1[k]
			r0[k] = fused_f32(x_cc, y, r0[k])
			r2[k] = fused_f32(b_cc, y, r2[k])
		}
	}
}
