// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

// Decode a non-visible frame that only fills a patch reference slot. Its
// planes are kept in source color space, before any color transform, at the
// frame's own size. Feature streams, LF dependencies, image upsampling and
// extra channels are outside this bounded subset.
fn decode_patch_reference_frame(file FileHeader, frame FrameHeader, storage ModularStorage, mut reader BitReader) !PatchFrameReference {
	if frame.frame_type != .reference_only || frame.is_last || !frame.can_be_referenced
		|| !frame.save_before_color_transform || frame.save_as_reference > 3 || frame.lf_level != 0
		|| frame.has_lf_frame() || frame.encoding != .modular || frame.has_patches() || frame.has_splines()
		|| frame.has_noise() || frame.upsampling != 1 || frame.do_ycbcr || !frame.is444()
		|| file.metadata.extra_channels.len != 0 {
		return error('Unsupported JPEG XL patch reference frame')
	}
	toc := reader.read_toc(int(frame.num_toc_entries()))!
	mut sections := reader.read_sections(toc)!
	raw := decode_modular_frame(file, frame, storage, mut sections)!
	planes := if file.metadata.xyb_encoded {
		render_modular_xyb_frame_impl(raw, file, frame, storage, false, []PatchFrameReference{})!
	} else {
		render_modular_rgb_frame(raw, file, frame, storage, []PatchFrameReference{})!
	}
	size := frame.size_upsampled()
	for plane in planes {
		if plane.width != int(size.width) || plane.height != int(size.height) {
			return error('Invalid JPEG XL patch reference geometry')
		}
	}
	return PatchFrameReference{
		info:   PatchReferenceInfo{ available: true, saved_before_color_transform: true,
			width: int(size.width), height: int(size.height) }
		planes: planes[..]
	}
}

// Apply a frame's patch dictionary to its restored color planes. As in the
// source pipeline this runs after Gaborish/EPF and before splines, image
// upsampling and noise. Frames with extra channels are rejected earlier.
fn apply_frame_patches(input [3]FloatPlane, patches PatchesDictionary, refs []PatchFrameReference) ![3]FloatPlane {
	width := input[0].width
	height := input[0].height
	for c in 0 .. 3 {
		input[c].validate()!
		if input[c].width != width || input[c].height != height {
			return error('Invalid JPEG XL patch plane geometry')
		}
	}
	mut samples := [3][]f32{}
	for c in 0 .. 3 { samples[c] = input[c].samples.clone() }
	mut row := [][]f32{len: 3}
	for y in 0 .. height {
		start := y * width
		for c in 0 .. 3 { row[c] = samples[c][start..start + width].clone() }
		patches.apply_row(mut row, 0, y, []ExtraChannelInfo{}, refs)!
		for c in 0 .. 3 {
			for x in 0 .. width { samples[c][start + x] = row[c][x] }
		}
	}
	return [FloatPlane{ width: width, height: height, samples: samples[0] },
		FloatPlane{ width: width, height: height, samples: samples[1] },
		FloatPlane{ width: width, height: height, samples: samples[2] }]!
}
