// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

pub struct VarDctEpfMaps {
pub:
	width         int
	height        int
	raw_quant     []i32
	transform_ids []u8
	sharpness     []u8
}

// Build inverse sigma for the existing EPF stages. A transform's top-left block
// has bit 7 set; its raw quantization applies to every covered block.
pub fn EpfSigma.vardct(maps VarDctEpfMaps, quantizer QuantizerParams, filter RestorationFilter) !EpfSigma {
	count := modular_sample_count(maps.width, maps.height)!
	if count == 0 || maps.raw_quant.len != count || maps.transform_ids.len != count || maps.sharpness.len != count {
		return error('Invalid JPEG XL VarDCT EPF map storage')
	}
	if quantizer.global_scale < 1 || quantizer.global_scale > 73728 || !math.is_finite(filter.epf_quant_multiplier) {
		return error('Invalid JPEG XL VarDCT EPF quantization scale')
	}
	for value in filter.epf_sharp_lut {
		if !math.is_finite(value) { return error('Invalid JPEG XL VarDCT EPF sharpness scale') }
	}
	mut values := []f32{len: count}
	mut covered := []bool{len: count}
	quant_scale := f32(1) / quantizer.inverse_global_scale()
	for by in 0 .. maps.height {
		for bx in 0 .. maps.width {
			p := by * maps.width + bx
			id := maps.transform_ids[p]
			if id < 128 {
				if !covered[p] { return error('Incomplete JPEG XL VarDCT EPF transform coverage') }
				continue
			}
			transform := hf_transform_from_id(int(id & 127))!
			dims := transform.covered_blocks()
			if dims[0] > maps.width - bx || dims[1] > maps.height - by || maps.raw_quant[p] <= 0 {
				return error('Invalid JPEG XL VarDCT EPF transform extent or quantization')
			}
			scaled_quant := quant_scale * f32(maps.raw_quant[p])
			denominator := scaled_quant * epf_inverse_sigma_numerator
			sigma_quant := filter.epf_quant_multiplier / denominator
			for iy in 0 .. dims[1] {
				for ix in 0 .. dims[0] {
					index := (by + iy) * maps.width + bx + ix
					if covered[index] { return error('Overlapping JPEG XL VarDCT EPF transforms') }
					sharpness := int(maps.sharpness[index])
					if sharpness >= 8 { return error('Invalid JPEG XL VarDCT EPF sharpness index') }
					scaled := sigma_quant * filter.epf_sharp_lut[sharpness]
					// Rust min chooses the finite cutoff when scaled is NaN (inf * 0).
					sigma := if scaled < f32(-1e-4) { scaled } else { f32(-1e-4) }
					values[index] = f32(1) / sigma
					covered[index] = true
				}
			}
		}
	}
	// The source's two extra SIMD padding columns do not contain visible sigma.
	return EpfSigma{ blocks: FloatPlane{ width: maps.width, height: maps.height, samples: values } }
}
