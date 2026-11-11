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
		|| frame.has_noise() || frame.upsampling != 1 || frame.do_ycbcr || !frame.is444() {
		return error('Unsupported JPEG XL patch reference frame')
	}
	toc := reader.read_toc(int(frame.num_toc_entries()))!
	mut sections := reader.read_sections(toc)!
	raw := decode_modular_frame(file, frame, storage, mut sections)!
	colors := if file.metadata.xyb_encoded || file.metadata.color_encoding.color_space != .gray { 3 } else { 1 }
	mut unpatched := FramePatchContext{}
	planes := if file.metadata.xyb_encoded {
		render_modular_xyb_frame_impl(raw, file, frame, storage, true, mut unpatched)!
	} else {
		render_modular_rgb_frame(raw, file, frame, storage, mut unpatched)!
	}
	extra := unscaled_extra_planes(file, frame, storage, raw.channels[colors..])!
	size := frame.size_upsampled()
	for plane in planes {
		if plane.width != int(size.width) || plane.height != int(size.height) {
			return error('Invalid JPEG XL patch reference geometry')
		}
	}
	mut all := planes[..]
	all << extra
	return PatchFrameReference{
		info:   PatchReferenceInfo{ available: true, saved_before_color_transform: true,
			width: int(size.width), height: int(size.height) }
		planes: all
	}
}

// Patch inputs for one frame: the four reference slots, the image's extra
// channel descriptions and, when the frame has patches and extra channels,
// their unscaled float planes, which patching updates alongside color.
struct FramePatchContext {
	refs []PatchFrameReference
	info []ExtraChannelInfo
mut:
	extra []FloatPlane
}

fn new_frame_patch_context(file FileHeader, frame FrameHeader, storage ModularStorage, refs []PatchFrameReference, channels []ModularChannel) !FramePatchContext {
	if !frame.has_patches() || channels.len == 0 {
		return FramePatchContext{ refs: refs, info: file.metadata.extra_channels }
	}
	return FramePatchContext{ refs: refs, info: file.metadata.extra_channels,
		extra: unscaled_extra_planes(file, frame, storage, channels)! }
}

// Patch stages run before any upsampling, so only full-resolution 8-bit extra
// channels are accepted; they are normalized as the final alpha output is.
fn unscaled_extra_planes(file FileHeader, frame FrameHeader, storage ModularStorage, channels []ModularChannel) ![]FloatPlane {
	if channels.len != file.metadata.extra_channels.len || frame.extra_upsampling.len != channels.len {
		return error('Invalid JPEG XL patch extra channel count')
	}
	size := frame.size_upsampled()
	mut planes := []FloatPlane{cap: channels.len}
	for i, channel in channels {
		extra := file.metadata.extra_channels[i]
		if frame.upsampling != 1 || frame.extra_upsampling[i] != 1 || extra.dimension_shift != 0
			|| extra.bit_depth.floating_point || extra.bit_depth.bits_per_sample != 8 {
			return error('Unsupported JPEG XL patch extra channel')
		}
		channel.validate()!
		if channel.width != int(size.width) || channel.height != int(size.height) {
			return error('Invalid JPEG XL patch extra channel geometry')
		}
		planes << FloatPlane{ width: channel.width, height: channel.height,
			samples: modular_integer_plane_to_f32(channel.samples, 8, storage)! }
	}
	return planes
}

// Apply a frame's patch dictionary to its restored color planes and, in
// place, its extra planes. As in the source pipeline this runs after
// Gaborish/EPF and before splines, image upsampling and noise.
fn (mut patch FramePatchContext) apply(input [3]FloatPlane, patches PatchesDictionary) ![3]FloatPlane {
	if patch.extra.len != patch.info.len {
		return error('JPEG XL patches require every extra channel plane')
	}
	width := input[0].width
	height := input[0].height
	for c in 0 .. 3 {
		input[c].validate()!
		if input[c].width != width || input[c].height != height {
			return error('Invalid JPEG XL patch plane geometry')
		}
	}
	for plane in patch.extra {
		plane.validate()!
		if plane.width != width || plane.height != height {
			return error('Invalid JPEG XL patch extra plane geometry')
		}
	}
	channels := 3 + patch.extra.len
	mut samples := [][]f32{cap: channels}
	for c in 0 .. 3 { samples << input[c].samples.clone() }
	for plane in patch.extra { samples << plane.samples.clone() }
	mut row := [][]f32{len: channels}
	for y in 0 .. height {
		start := y * width
		for c in 0 .. channels { row[c] = samples[c][start..start + width].clone() }
		patches.apply_row(mut row, 0, y, patch.info, patch.refs)!
		for c in 0 .. channels {
			for x in 0 .. width { samples[c][start + x] = row[c][x] }
		}
	}
	for i in 0 .. patch.extra.len {
		patch.extra[i] = FloatPlane{ width: width, height: height, samples: samples[3 + i] }
	}
	return [FloatPlane{ width: width, height: height, samples: samples[0] },
		FloatPlane{ width: width, height: height, samples: samples[1] },
		FloatPlane{ width: width, height: height, samples: samples[2] }]!
}

fn apply_frame_patches(input [3]FloatPlane, patches PatchesDictionary, refs []PatchFrameReference) ![3]FloatPlane {
	mut patch := FramePatchContext{ refs: refs }
	return patch.apply(input, patches)
}
