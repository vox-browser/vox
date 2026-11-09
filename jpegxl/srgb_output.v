// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

pub struct SrgbOutputColor {
pub:
	opsin            OpsinInverseMatrix
	intensity_target f32
}

// Prepare the source renderer's sRGB/gray XYB output matrix. Profiles requiring
// ICC processing, other primaries or other transfer curves remain unsupported.
pub fn prepare_srgb_output(file FileHeader) !SrgbOutputColor {
	color := file.metadata.color_encoding
	if color.want_icc || color.color_space !in [.rgb, .gray, .xyb] {
		return error('JPEG XL output requires an unsupported color profile')
	}
	if color.color_space == .xyb {
		if !file.metadata.xyb_encoded || color.rendering_intent != .perceptual {
			return error('JPEG XL XYB profile requires XYB encoding and perceptual intent')
		}
	} else if color.white_point != .d65 || color.have_gamma || color.transfer_function != .srgb
		|| (color.color_space == .rgb && color.primaries != .srgb) {
		return error('JPEG XL output requires sRGB or D65 gray')
	}
	opsin := file.transform.opsin
	intensity := file.metadata.tone_mapping.intensity_target
	// Use the same checked setup as conversion, including finite matrix/biases.
	xyb_parameters(opsin, intensity)!
	mut matrix := opsin.inverse_matrix
	if color.color_space == .gray {
		luminances := [f32(0.2126), 0.7152, 0.0722]!
		for column in 0 .. 3 {
			// Rust's floating-point iterator sum starts with -0.0, preserving
			// the sign when every product in a column is negative zero.
			mut sum := math.f64_from_bits(0x8000000000000000)
			for k in 0 .. 3 { sum += f64(luminances[k]) * f64(opsin.inverse_matrix[k * 3 + column]) }
			if !math.is_finite(sum) { return error('Nonfinite JPEG XL grayscale matrix') }
			for row in 0 .. 3 { matrix[row * 3 + column] = f32(sum) }
		}
	}
	return SrgbOutputColor{ opsin: OpsinInverseMatrix{ ...opsin, inverse_matrix: matrix }, intensity_target: intensity }
}
