// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub enum ChromaAxis {
	horizontal
	vertical
}

// Produces the full doubled extent. Frame-level cropping belongs to the caller.
pub fn chroma_upsample_plane(input FloatPlane, axis ChromaAxis) !FloatPlane {
	input.validate()!
	width := if axis == .horizontal { input.width * 2 } else { input.width }
	height := if axis == .vertical { input.height * 2 } else { input.height }
	count := modular_sample_count(width, height)!
	mut result := []f32{len: count}
	for y in 0 .. input.height {
		for x in 0 .. input.width {
			center := input.samples[y * input.width + x] * f32(0.75)
			if axis == .horizontal {
				result[y * width + 2 * x] = fused_f32(input.at_border(x - 1, y), f32(0.25), center)
				result[y * width + 2 * x + 1] = fused_f32(input.at_border(x + 1, y), f32(0.25), center)
			} else {
				result[2 * y * width + x] = fused_f32(input.at_border(x, y - 1), f32(0.25), center)
				result[(2 * y + 1) * width + x] = fused_f32(input.at_border(x, y + 1), f32(0.25), center)
			}
		}
	}
	return FloatPlane{ width: width, height: height, samples: result }
}
