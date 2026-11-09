// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

pub struct VarDctLfParameters {
pub:
	width             int
	height            int
	horizontal_shift  [3]u32
	vertical_shift    [3]u32
	extra_precision   u32
	quantizer         QuantizerParams
	lf_quant          LfQuantFactors
	color_correlation ColorCorrelationParams
	block_context     BlockContextMap
}

pub struct VarDctLfResult {
pub:
	width             int
	height            int
	planes            []FloatPlane
	quant_lf_contexts []u8
}

// Input channels are encoded Y, X, B integers; output planes are X, Y, B floats.
// Geometry describes a complete padded LF group, including subsampling alignment.
pub fn reconstruct_vardct_lf(input []ModularChannel, parameters VarDctLfParameters) !VarDctLfResult {
	p := parameters
	count := modular_sample_count(p.width, p.height)!
	if count == 0 || input.len != 3 || p.extra_precision > 3 {
		return error('Invalid JPEG XL VarDCT LF dimensions or precision')
	}
	if p.quantizer.global_scale < 1 || p.quantizer.global_scale > 73728
		|| p.quantizer.quant_lf < 1 || p.quantizer.quant_lf > 65536 {
		return error('Invalid JPEG XL VarDCT LF quantizer')
	}
	cc := p.color_correlation
	if cc.color_factor < 2 || cc.color_factor > 65793 || !math.is_finite(cc.base_correlation_x)
		|| !math.is_finite(cc.base_correlation_b) || math.abs(cc.base_correlation_x) > f32(4)
		|| math.abs(cc.base_correlation_b) > f32(4) || cc.ytox_lf < -128 || cc.ytox_lf > 127
		|| cc.ytob_lf < -128 || cc.ytob_lf > 127 {
		return error('Invalid JPEG XL VarDCT LF color correlation')
	}
	mut lf_contexts := 1
	mut samples := u64(count)
	for c in 0 .. 3 {
		if p.horizontal_shift[c] > 1 || p.vertical_shift[c] > 1
			|| p.width % (1 << p.horizontal_shift[c]) != 0 || p.height % (1 << p.vertical_shift[c]) != 0 {
			return error('Invalid JPEG XL VarDCT LF subsampling alignment')
		}
		coded := if c < 2 { c ^ 1 } else { 2 }
		input[coded].validate()!
		if input[coded].width != p.width >> p.horizontal_shift[c] || input[coded].height != p.height >> p.vertical_shift[c] {
			return error('Incompatible JPEG XL VarDCT LF channel geometry')
		}
		samples += u64(input[coded].samples.len)
		if p.block_context.lf_thresholds[c].len > 15 {
			return error('Invalid JPEG XL VarDCT LF threshold count')
		}
		lf_contexts *= p.block_context.lf_thresholds[c].len + 1
		if !math.is_finite(p.lf_quant.quant_factors[c]) || p.lf_quant.quant_factors[c] < f32(1e-8) {
			return error('Invalid JPEG XL VarDCT LF quantization factor')
		}
	}
	if samples > 67108864 || lf_contexts > 64 || p.block_context.num_lf_contexts != lf_contexts {
		return error('Invalid JPEG XL VarDCT LF sample or context count')
	}
	// The source divides by the rounded product here; inverse_quant_lf() uses two divisions.
	quant_denominator := f32(p.quantizer.global_scale) * f32(p.quantizer.quant_lf)
	inverse_quant := f32(65536) / quant_denominator
	multiplier := f32(1) / f32(u32(1) << p.extra_precision)
	mut factors := [3]f32{}
	mut output := [][]f32{cap: 3}
	for c in 0 .. 3 {
		factor := p.lf_quant.quant_factors[c] * inverse_quant
		factors[c] = factor * multiplier
		coded := if c < 2 { c ^ 1 } else { 2 }
		output << input[coded].samples.map(f32(it) * factors[c])
	}
	if p.horizontal_shift.all(it == 0) && p.vertical_shift.all(it == 0) {
		factor_x := cc.y_to_x_lf()
		factor_b := cc.y_to_b_lf()
		for i in 0 .. count {
			x_correlation := output[1][i] * factor_x
			b_correlation := output[1][i] * factor_b
			output[0][i] = x_correlation + output[0][i]
			output[2][i] = b_correlation + output[2][i]
		}
	}
	mut contexts := []u8{len: count}
	if lf_contexts > 1 {
		for y in 0 .. p.height {
			for x in 0 .. p.width {
				mut buckets := [3]int{}
				for c in 0 .. 3 {
					coded := if c < 2 { c ^ 1 } else { 2 }
					index := (y >> p.vertical_shift[c]) * input[coded].width + (x >> p.horizontal_shift[c])
					for threshold in p.block_context.lf_thresholds[c] {
						if input[coded].samples[index] > threshold { buckets[c]++ }
					}
				}
				contexts[y * p.width + x] = u8((buckets[0] * (p.block_context.lf_thresholds[2].len + 1) + buckets[2]) * (p.block_context.lf_thresholds[1].len + 1) + buckets[1])
			}
		}
	}
	mut planes := []FloatPlane{cap: 3}
	for c in 0 .. 3 {
		planes << FloatPlane{ width: p.width >> p.horizontal_shift[c], height: p.height >> p.vertical_shift[c], samples: output[c] }
	}
	return VarDctLfResult{ width: p.width, height: p.height, planes: planes, quant_lf_contexts: contexts }
}
