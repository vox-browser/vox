// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct LfQuantFactors {
pub:
	quant_factors   [3]f32
	inverse_factors [3]f32
}

pub fn (mut reader BitReader) read_lf_quant_factors() !LfQuantFactors {
	mut factors := [f32(1.0 / 4096.0), f32(1.0 / 512.0), f32(1.0 / 256.0)]!
	if reader.read(1)! == 0 {
		for i in 0 .. 3 {
			factors[i] = reader.read_f16()! / f32(128)
			if factors[i] < f32(1e-8) {
				return error('JPEG XL LF quantization factor is too small')
			}
		}
	}
	return LfQuantFactors{
		quant_factors:   factors
		inverse_factors: [f32(1) / factors[0], f32(1) / factors[1], f32(1) / factors[2]]!
	}
}
