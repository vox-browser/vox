// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

// Complete-file output for the currently assembled opaque 4:4:4 VarDCT subset.
// This is not the production replacement: references, feature streams, alpha,
// resampling and frame composition must be preserved before switching callers.
pub fn decode_vardct_rgba(input []u8, premultiply bool) !RgbaImage {
	if input.len < 2 || input.len > 67108864 { return error('Invalid JPEG XL input size') }
	mut reader := new_bit_reader(extract_codestream(input)!)
	file := reader.read_file_header()!
	metadata := file.metadata
	if metadata.animation != none || metadata.preview != none || metadata.extra_channels.len != 0
		|| metadata.bit_depth.floating_point || metadata.bit_depth.bits_per_sample != 8
		|| file.size.width == 0 || file.size.height == 0 || file.size.width > 65536 || file.size.height > 65536
		|| u64(file.size.width) * u64(file.size.height) > 67108864 / 4 {
		return error('JPEG XL file requires unsupported VarDCT output services')
	}
	color := prepare_srgb_output(file)!
	context := file.frame_header_context()
	mut frame := reader.read_frame_header(context)!
	frame.postprocess(context)!
	if !frame.is_last || frame.frame_type != .regular || frame.lf_level != 0 || frame.needs_blending()
		|| frame.width != file.size.width || frame.height != file.size.height || frame.x0 != 0 || frame.y0 != 0 {
		return error('JPEG XL VarDCT output requires one full visible frame')
	}
	validate_vardct_frame_subset(file, frame)!
	toc := reader.read_toc(int(frame.num_toc_entries()))!
	mut sections := reader.read_sections(toc)!
	if reader.available_bits() != 0 { return error('Unhandled JPEG XL VarDCT trailing payload') }
	storage := if metadata.modular_16bit_sufficient { ModularStorage.signed16 } else { ModularStorage.signed32 }
	raw := decode_vardct_frame(file, frame, storage, mut sections)!
	restored := restore_vardct_frame(raw, frame)!
	output := if metadata.xyb_encoded {
		linear := xyb_to_linear(restored, color.opsin, color.intensity_target)!
		[srgb_transfer(linear[0], .from_linear)!, srgb_transfer(linear[1], .from_linear)!, srgb_transfer(linear[2], .from_linear)!]!
	} else if frame.do_ycbcr {
		converted := ycbcr_to_rgb_planes(restored[..])!
		[converted[0],converted[1],converted[2]]!
	} else if metadata.color_encoding.color_space == .gray {
		[restored[0],restored[0],restored[0]]!
	} else {
		restored
	}
	display := metadata.orientation.map_size(file.size)
	pitch := int(display.width) * 4
	mut pixels := []u8{len: pitch * int(display.height)}
	for y in 0 .. int(file.size.height) {
		mut rows := [][]u8{cap: 3}
		for c in 0 .. 3 {
			start := y * int(file.size.width)
			rows << quantize_output_row(output[c].samples[start..start + int(file.size.width)], 0, u32(y), u32(c), 8)!
		}
		for x in 0 .. int(file.size.width) {
			dx, dy := metadata.orientation.display_pixel(u32(x), u32(y), file.size)!
			index := int(dy) * pitch + int(dx) * 4
			for c in 0 .. 3 { pixels[index + c] = rows[c][x] }
			// With no alpha channel straight and premultiplied output coincide.
			pixels[index + 3] = 255
		}
	}
	return RgbaImage{ width: int(display.width), height: int(display.height), pitch: pitch, pixels: pixels }
}
