// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

enum ImageRgbaMode {
	vardct_only
	opaque
	all_static
}

// Combine the translated static VarDCT and modular image paths. One 8-bit
// alpha channel can use 1x/2x/4x/8x sampling. Wider features/frame composition
// remain separate from this bounded subset of the production decoder.
pub fn decode_rgba(input []u8, premultiply bool) !RgbaImage {
	return decode_image_rgba_impl(input, premultiply, .all_static)
}
