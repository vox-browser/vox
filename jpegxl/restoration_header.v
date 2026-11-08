// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

pub struct RestorationFilter {
pub:
	gab                       bool   = true
	gab_weights               [6]f32 = [f32(0.115169525), 0.061248592, 0.115169525, 0.061248592,
		0.115169525, 0.061248592]!
	epf_iterations            u32    = 2
	epf_sharp_lut             [8]f32 = [f32(0), f32(1) / f32(7), f32(2) / f32(7), f32(3) / f32(7),
		f32(4) / f32(7), f32(5) / f32(7), f32(6) / f32(7), f32(1)]!
	epf_channel_scale         [3]f32
	epf_pass1_zeroflush       f32 = 0.45
	epf_pass2_zeroflush       f32 = 0.6
	epf_quant_multiplier      f32 = 0.46
	epf_pass0_sigma_scale     f32 = 0.9
	epf_pass2_sigma_scale     f32 = 6.5
	epf_border_sad_multiplier f32 = f32(2) / f32(3)
	epf_sigma_for_modular     f32 = 1
}

pub fn RestorationFilter.default() RestorationFilter {
	return RestorationFilter{
		gab_weights:       [f32(0.115169525), 0.061248592, 0.115169525, 0.061248592, 0.115169525,
			0.061248592]!
		epf_sharp_lut:     [f32(0), f32(1) / f32(7), f32(2) / f32(7), f32(3) / f32(7), f32(4) / f32(7),
			f32(5) / f32(7), f32(6) / f32(7), f32(1)]!
		epf_channel_scale: [f32(40), 5, 3.5]!
	}
}

pub fn (mut reader BitReader) read_restoration_filter(encoding FrameEncoding) !RestorationFilter {
	if reader.read(1)! != 0 { return RestorationFilter.default() }
	defaults := RestorationFilter.default()
	gab := reader.read(1)! != 0
	gab_custom := if gab { reader.read(1)! != 0 } else { false }
	mut weights := [6]f32{}
	for i, value in defaults.gab_weights { weights[i] = value }
	if gab_custom {
		for i in 0 .. 6 { weights[i] = reader.read_f16()! }
	}
	iterations := u32(reader.read(2)!)
	sharp_custom := if iterations > 0 && encoding == .vardct { reader.read(1)! != 0 } else { false }
	mut sharp := [8]f32{}
	for i, value in defaults.epf_sharp_lut { sharp[i] = value }
	if sharp_custom {
		for i in 0 .. 8 { sharp[i] = reader.read_f16()! }
	}
	weight_custom := if iterations > 0 { reader.read(1)! != 0 } else { false }
	mut scale := [3]f32{}
	for i, value in defaults.epf_channel_scale { scale[i] = value }
	mut zero1 := defaults.epf_pass1_zeroflush
	mut zero2 := defaults.epf_pass2_zeroflush
	if weight_custom {
		for i in 0 .. 3 { scale[i] = reader.read_f16()! }
		zero1 = reader.read_f16()!
		zero2 = reader.read_f16()!
	}
	sigma_custom := if iterations > 0 { reader.read(1)! != 0 } else { false }
	quant := if sigma_custom && encoding == .vardct {
		reader.read_f16()!
	} else {
		defaults.epf_quant_multiplier
	}
	pass0 := if sigma_custom { reader.read_f16()! } else { defaults.epf_pass0_sigma_scale }
	pass2 := if sigma_custom { reader.read_f16()! } else { defaults.epf_pass2_sigma_scale }
	border := if sigma_custom { reader.read_f16()! } else { defaults.epf_border_sad_multiplier }
	modular := if iterations > 0 && encoding == .modular {
		reader.read_f16()!
	} else {
		defaults.epf_sigma_for_modular
	}
	reader.skip_extensions()!
	for i in 0 .. 3 {
		value := f32(1) + (weights[i * 2] + weights[i * 2 + 1]) * f32(4)
		if f32(math.abs(f64(value))) < f32(0.000001) {
			return error('Invalid JPEG XL Gaborish normalization')
		}
	}
	if !math.is_finite(f64(modular)) || modular <= 0 {
		return error('Invalid JPEG XL modular EPF sigma')
	}
	return RestorationFilter{
		gab:                       gab
		gab_weights:               weights
		epf_iterations:            iterations
		epf_sharp_lut:             sharp
		epf_channel_scale:         scale
		epf_pass1_zeroflush:       zero1
		epf_pass2_zeroflush:       zero2
		epf_quant_multiplier:      quant
		epf_pass0_sigma_scale:     pass0
		epf_pass2_sigma_scale:     pass2
		epf_border_sad_multiplier: border
		epf_sigma_for_modular:     modular
	}
}
