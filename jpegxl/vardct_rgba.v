// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

// Complete-file output for the assembled opaque VarDCT subset.
pub fn decode_vardct_rgba(input []u8, premultiply bool) !RgbaImage {
	return decode_image_rgba_impl(input, premultiply, .vardct_only)
}

// Opaque VarDCT and modular XYB output, including LF frames and image
// upsampling. Extra channels, feature streams and wider frame composition must
// be preserved before this can replace the production decoder.
pub fn decode_opaque_rgba(input []u8, premultiply bool) !RgbaImage {
	return decode_image_rgba_impl(input, premultiply, .opaque)
}

fn decode_image_rgba_impl(input []u8, premultiply bool, mode ImageRgbaMode) !RgbaImage {
	allow_alpha := mode == .all_static
	allow_modular_xyb := mode != .vardct_only
	if input.len < 2 || input.len > 67108864 { return error('Invalid JPEG XL input size') }
	mut reader := new_bit_reader(extract_codestream(input)!)
	file := reader.read_file_header()!
	metadata := file.metadata
	if metadata.animation != none || metadata.extra_channels.len > 1 || (!allow_alpha && metadata.extra_channels.len != 0)
		|| metadata.bit_depth.floating_point || metadata.bit_depth.bits_per_sample != 8
		|| file.size.width == 0 || file.size.height == 0 || file.size.width > 65536 || file.size.height > 65536
		|| u64(file.size.width) * u64(file.size.height) > 67108864 / 4 {
		return error('JPEG XL file requires unsupported VarDCT output services')
	}
	for extra in metadata.extra_channels {
		if extra.kind != .alpha || extra.dimension_shift != 0 || extra.bit_depth.floating_point || extra.bit_depth.bits_per_sample != 8 {
			return error('JPEG XL output requires one 8-bit alpha channel')
		}
	}
	color := prepare_srgb_output(file)!
	reader.skip_preview(file)!
	context := file.frame_header_context()
	storage := if metadata.modular_16bit_sufficient { ModularStorage.signed16 } else { ModularStorage.signed32 }
	mut references := []LfFrameReference{len: 4}
	mut patch_refs := []PatchFrameReference{len: 4}
	mut patch := FramePatchContext{}
	mut frame := FrameHeader{ restoration: RestorationFilter.default() }
	mut restored := [3]FloatPlane{}
	mut extra_channels := []ModularChannel{}
	mut found := false
	for _ in 0 .. 64 {
		frame = reader.read_frame_header(context)!
		frame.postprocess(context)!
		if frame.frame_type == .reference_only {
			patch_refs[int(frame.save_as_reference)] = decode_patch_reference_frame(file, frame, storage, mut reader)!
			continue
		}
		if frame.frame_type != .lf && (!frame.is_last || frame.frame_type != .regular || frame.lf_level != 0 || frame.needs_blending()
			|| frame.width != file.size.width || frame.height != file.size.height || frame.x0 != 0 || frame.y0 != 0) {
			return error('JPEG XL VarDCT output requires one full visible frame')
		}
		reference := if frame.has_lf_frame() { references[int(frame.lf_level)].planes } else { ?[3]FloatPlane(none) }
		if frame.frame_type == .lf {
			validate_lf_reference_frame(file, frame)!
		} else if frame.encoding == .modular {
			if !allow_modular_xyb { return error('JPEG XL VarDCT output requires a VarDCT visible frame') }
			if !metadata.xyb_encoded && mode == .all_static {
				validate_modular_rgb_frame(file, frame)!
			} else {
				validate_modular_xyb_frame_alpha(file, frame, allow_alpha)!
			}
		} else {
			validate_vardct_frame_reference(file, frame, reference)!
		}
		toc := reader.read_toc(int(frame.num_toc_entries()))!
		mut sections := reader.read_sections(toc)!
		if frame.frame_type == .lf {
			planes := decode_lf_reference_frame(file, frame, storage, reference, mut sections)!
			references[int(frame.lf_level) - 1] = LfFrameReference{ planes: planes }
			continue
		}
		if frame.encoding == .modular {
			raw := decode_modular_frame_refs(file, frame, storage, patch_refs.map(it.info), mut sections)!
			colors := if metadata.xyb_encoded || metadata.color_encoding.color_space != .gray { 3 } else { 1 }
			patch = new_frame_patch_context(file, frame, storage, patch_refs, raw.channels[colors..])!
			if metadata.xyb_encoded {
				restored = render_modular_xyb_frame_impl(raw, file, frame, storage, allow_alpha, mut patch)!
				extra_channels = raw.channels[3..]
			} else {
				restored = render_modular_rgb_frame(raw, file, frame, storage, mut patch)!
				extra_channels = raw.channels[colors..]
			}
		} else {
			raw := decode_vardct_frame_with_refs(file, frame, storage, reference, patch_refs.map(it.info), mut sections)!
			patch = new_frame_patch_context(file, frame, storage, patch_refs, raw.extra_channels)!
			restored = render_vardct_frame(raw, frame, file.transform, mut patch)!
			extra_channels = raw.extra_channels
		}
		found = true
		break
	}
	if !found { return error('JPEG XL non-visible frame limit exceeded') }
	if reader.available_bits() != 0 { return error('Unhandled JPEG XL VarDCT trailing payload') }
	if extra_channels.len != metadata.extra_channels.len { return error('Incorrect JPEG XL output extra channel count') }
	mut alpha_samples := []f32{}
	if patch.extra.len == 1 {
		alpha_samples = patch.extra[0].samples
	} else if extra_channels.len == 1 {
		alpha_plane := render_alpha_plane(extra_channels[0], file, frame, storage)!
		alpha_samples = alpha_plane.samples
	}
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
	has_alpha := extra_channels.len == 1
	should_premultiply := has_alpha && premultiply && !metadata.extra_channels[0].alpha_associated
	width := int(file.size.width)
	identity := metadata.orientation == .identity
	mut alpha_bytes := []u8{len: if has_alpha { width } else { 0 }}
	mut rows := [3][]u8{}
	for c in 0 .. 3 { rows[c] = []u8{len: width} }
	for y in 0 .. int(file.size.height) {
		start := y * width
		end := start + width
		alpha := if has_alpha { alpha_samples[start..end] } else { []f32{} }
		if has_alpha { quantize_output_row_into(alpha, 0, u32(y), 3, 8, mut alpha_bytes)! }
		for c in 0 .. 3 {
			color_row := output[c].samples[start..end]
			row := if should_premultiply { premultiply_output_row(color_row, alpha)! } else { color_row }
			quantize_output_row_into(row, 0, u32(y), u32(c), 8, mut rows[c])!
		}
		if identity {
			// Identity orientation stores rows in order; pitch is width * 4.
			mut index := y * pitch
			for x in 0 .. width {
				pixels[index] = rows[0][x]
				pixels[index + 1] = rows[1][x]
				pixels[index + 2] = rows[2][x]
				pixels[index + 3] = if has_alpha { alpha_bytes[x] } else { 255 }
				index += 4
			}
			continue
		}
		for x in 0 .. width {
			dx, dy := metadata.orientation.display_pixel(u32(x), u32(y), file.size)!
			index := int(dy) * pitch + int(dx) * 4
			for c in 0 .. 3 { pixels[index + c] = rows[c][x] }
			pixels[index + 3] = if has_alpha { alpha_bytes[x] } else { 255 }
		}
	}
	return RgbaImage{ width: int(display.width), height: int(display.height), pitch: pitch, pixels: pixels }
}
