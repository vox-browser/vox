// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

// Combine the translated static image paths. VarDCT and modular XYB can carry
// one unscaled 8-bit alpha channel; lossless modular retains its existing
// bounds. This remains a subset of the production decoder.
pub fn decode_rgba(input []u8, premultiply bool) !RgbaImage {
	if input.len < 2 || input.len > 67108864 { return error('Invalid JPEG XL input size') }
	mut reader := new_bit_reader(extract_codestream(input)!)
	file := reader.read_file_header()!
	if !file.metadata.xyb_encoded {
		reader.skip_preview(file)!
		context := file.frame_header_context()
		mut first := reader.read_frame_header(context)!
		first.postprocess(context)!
		if first.encoding == .modular && first.frame_type == .regular {
			return decode_lossless_rgba(input, premultiply)
		}
	}
	return decode_image_rgba_impl(input, premultiply, true, true)
}
