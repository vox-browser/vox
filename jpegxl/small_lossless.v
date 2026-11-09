// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct RgbaImage {
pub:
	width  int
	height int
	pitch  int
	pixels []u8
}

fn validate_small_lossless_file(file FileHeader) ! {
	metadata := file.metadata
	color := metadata.color_encoding
	if file.size.width == 0 || file.size.height == 0 || file.size.width > 65536 || file.size.height > 65536 || u64(file.size.width) * u64(file.size.height) * 4 > 67108864 {
		return error('JPEG XL RGBA image exceeds output limits')
	}
	if metadata.animation != none || metadata.xyb_encoded || metadata.bit_depth.floating_point || metadata.bit_depth.bits_per_sample != 8 {
		return error('JPEG XL file requires unsupported image services')
	}
	if color.want_icc || color.color_space !in [.rgb, .gray] || color.white_point != .d65 || color.have_gamma || color.transfer_function != .srgb || (color.color_space == .rgb && color.primaries != .srgb) {
		return error('JPEG XL small lossless output requires sRGB or gray')
	}
	if metadata.extra_channels.len > 1 {
		return error('JPEG XL small lossless output supports at most one alpha channel')
	}
	for extra in metadata.extra_channels {
		if extra.kind != .alpha || extra.bit_depth.floating_point || extra.bit_depth.bits_per_sample != 8 || extra.dimension_shift != 0 {
			return error('JPEG XL extra channel requires unsupported output services')
		}
	}
}

fn validate_small_lossless_frame(file FileHeader, frame FrameHeader) ! {
	if frame.encoding != .modular || frame.frame_type != .regular || !frame.is_last || frame.lf_level != 0 || frame.needs_blending() || frame.width != file.size.width || frame.height != file.size.height || frame.x0 != 0 || frame.y0 != 0 {
		return error('JPEG XL small lossless output requires one full modular frame')
	}
	if frame.upsampling != 1 || !frame.is444() || frame.extra_upsampling.any(it != 1) || frame.flags & ~u64(0x80) != 0 || frame.restoration.gab || frame.restoration.epf_iterations != 0 {
		return error('JPEG XL frame requires unsupported sampling, filters or groups')
	}
}

// Complete-file entry point for the currently translated lossless subset.
// Grouped/progressive frames, XYB/YCbCr, filters and frame composition still
// require the production decoder; callers must not treat this as its replacement.
pub fn decode_small_lossless_rgba(input []u8, premultiply bool) !RgbaImage {
	return decode_lossless_rgba_impl(input, premultiply, true)
}

// Full-frame lossless output, including grouped and multipass modular channels.
// XYB/YCbCr, filters, previews and frame composition remain unsupported.
pub fn decode_lossless_rgba(input []u8, premultiply bool) !RgbaImage {
	return decode_lossless_rgba_impl(input, premultiply, false)
}

fn decode_lossless_rgba_impl(input []u8, premultiply bool, small_only bool) !RgbaImage {
	if input.len < 2 || input.len > 67108864 { return error('Invalid JPEG XL input size') }
	mut reader := new_bit_reader(extract_codestream(input)!)
	file := reader.read_file_header()!
	validate_small_lossless_file(file)!
	reader.skip_preview(file)!
	context := file.frame_header_context()
	mut frame := reader.read_frame_header(context)!
	frame.postprocess(context)!
	validate_small_lossless_frame(file, frame)!
	if (small_only && frame.num_toc_entries() != 1) || frame.num_toc_entries() > u64(max_permutation_entries) {
		return error('JPEG XL lossless frame has unsupported group count')
	}
	toc := reader.read_toc(int(frame.num_toc_entries()))!
	mut sections := reader.read_sections(toc)!
	storage := if file.metadata.modular_16bit_sufficient {
		ModularStorage.signed16
	} else {
		ModularStorage.signed32
	}
	raw := decode_modular_frame(file, frame, storage, mut sections)!
	if reader.available_bits() != 0 {
		return error('JPEG XL small lossless frame has unhandled payload')
	}
	gray := file.metadata.color_encoding.color_space == .gray
	colors := if gray { 1 } else { 3 }
	has_alpha := file.metadata.extra_channels.len == 1
	if raw.channels.len != colors + file.metadata.extra_channels.len {
		return error('Incorrect JPEG XL output channel count')
	}
	width := int(file.size.width)
	height := int(file.size.height)
	for channel in raw.channels {
		channel.validate()!
		if channel.width != width || channel.height != height {
			return error('JPEG XL output channel requires resampling')
		}
	}
	should_premultiply := premultiply && has_alpha && !file.metadata.extra_channels[0].alpha_associated
	display := file.metadata.orientation.map_size(file.size)
	pitch := int(display.width) * 4
	mut pixels := []u8{len: pitch * int(display.height)}
	for y in 0 .. height {
		start := y * width
		end := start + width
		alpha := if has_alpha {
			modular_integer_row_to_f32(raw.channels[colors].samples[start..end], 8, storage)!
		} else {
			[]f32{len: width, init: f32(1)}
		}
		alpha_bytes := quantize_output_row(alpha, 0, u32(y), 3, 8)!
		mut rows := [][]u8{cap: 3}
		for c in 0 .. 3 {
			index := if gray { 0 } else { c }
			color := modular_integer_row_to_f32(raw.channels[index].samples[start..end], 8, storage)!
			output := if should_premultiply { premultiply_output_row(color, alpha)! } else { color }
			rows << quantize_output_row(output, 0, u32(y), u32(c), 8)!
		}
		for x in 0 .. width {
			dx, dy := file.metadata.orientation.display_pixel(u32(x), u32(y), file.size)!
			offset := int(dy) * pitch + int(dx) * 4
			for c in 0 .. 3 { pixels[offset + c] = rows[c][x] }
			pixels[offset + 3] = alpha_bytes[x]
		}
	}
	return RgbaImage{ width: int(display.width), height: int(display.height), pitch: pitch, pixels: pixels }
}
