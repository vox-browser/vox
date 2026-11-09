// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

// Source channel order is Cb,Y,Cr. Output order is R,G,B, without clipping.
// Plane geometry and resampling are resolved before this conversion stage.
pub fn ycbcr_to_rgb_planes(input []FloatPlane) ![]FloatPlane {
	if input.len != 3 { return error('JPEG XL YCbCr conversion requires three planes') }
	for plane in input {
		plane.validate()!
		if plane.width != input[0].width || plane.height != input[0].height {
			return error('Incompatible JPEG XL YCbCr plane dimensions')
		}
	}
	cr_to_g := (f32(-0.299) * f32(1.402)) / f32(0.587)
	cb_to_g := (f32(-0.114) * f32(1.772)) / f32(0.587)
	mut red := []f32{len: input[0].samples.len}
	mut green := []f32{len: red.len}
	mut blue := []f32{len: red.len}
	for i in 0 .. red.len {
		cb := input[0].samples[i]
		y := input[1].samples[i] + f32(128) / f32(255)
		cr := input[2].samples[i]
		red[i] = fused_f32(cr, f32(1.402), y)
		green[i] = fused_f32(cr, cr_to_g, fused_f32(cb, cb_to_g, y))
		blue[i] = fused_f32(cb, f32(1.772), y)
	}
	return [
		FloatPlane{ width: input[0].width, height: input[0].height, samples: red },
		FloatPlane{ width: input[0].width, height: input[0].height, samples: green },
		FloatPlane{ width: input[0].width, height: input[0].height, samples: blue },
	]
}
