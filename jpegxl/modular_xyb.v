// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

// Modular XYB stores Y, X and a B residual. The source adds Y to B after
// converting both integers to f32, then scales that sum with B's factor.
pub fn modular_xyb_planes(input []ModularChannel, quantization LfQuantFactors, storage ModularStorage) ![3]FloatPlane {
	if input.len != 3 { return error('JPEG XL modular XYB requires three channels') }
	for plane in input {
		plane.validate()!
		if plane.width != input[0].width || plane.height != input[0].height {
			return error('Incompatible JPEG XL modular XYB geometry')
		}
	}
	if u64(input[0].samples.len) * 3 > 67108864 { return error('JPEG XL modular XYB sample budget exceeded') }
	for scale in quantization.quant_factors {
		if !math.is_finite(scale) || scale < f32(1e-8) { return error('Invalid JPEG XL modular XYB scale') }
	}
	mut samples := [3][]f32{}
	for c in 0 .. 3 { samples[c] = []f32{len: input[0].samples.len} }
	for i in 0 .. input[0].samples.len {
		y := f32(modular_storage_value(input[0].samples[i], storage))
		x := f32(modular_storage_value(input[1].samples[i], storage))
		b := f32(modular_storage_value(input[2].samples[i], storage))
		samples[0][i] = x * quantization.quant_factors[0]
		samples[1][i] = y * quantization.quant_factors[1]
		sum := b + y
		samples[2][i] = sum * quantization.quant_factors[2]
	}
	mut output := [3]FloatPlane{}
	for c in 0 .. 3 { output[c] = FloatPlane{ width: input[c].width, height: input[c].height, samples: samples[c] } }
	return output
}
