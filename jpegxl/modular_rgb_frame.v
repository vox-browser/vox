// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

fn validate_modular_rgb_frame(file FileHeader, frame FrameHeader) ! {
	validate_small_lossless_file(file)!
	validate_modular_group_geometry(frame)!
	if frame.encoding != .modular || frame.frame_type !in [.regular, .reference_only] || frame.lf_level != 0
		|| !frame.is444() || frame.do_ycbcr || frame.has_lf_frame()
		|| frame.has_splines() || frame.has_noise() || frame.extra_upsampling.len != file.metadata.extra_channels.len {
		return error('Unsupported JPEG XL modular RGB rendering services')
	}
	for factor in frame.extra_upsampling {
		if factor !in [u32(1), 2, 4, 8] || factor < frame.upsampling {
			return error('Unsupported JPEG XL modular RGB alpha sampling')
		}
	}
	size := frame.size()
	colors := if file.metadata.color_encoding.color_space == .gray { 1 } else { 3 }
	if u64(size.width) * u64(size.height) > 67108864 / u64(colors + file.metadata.extra_channels.len) {
		return error('JPEG XL modular RGB sample budget exceeded')
	}
}

// Normalize original-profile integers before color restoration and image
// upsampling. The final owner applies alpha and positional byte quantization.
fn render_modular_rgb_frame(raw ModularFramePlanes, file FileHeader, frame FrameHeader, storage ModularStorage, patch_refs []PatchFrameReference) ![3]FloatPlane {
	validate_modular_rgb_frame(file, frame)!
	if frame.has_patches() != (raw.patches != none) { return error('JPEG XL patch dictionary disagrees with the frame') }
	gray := file.metadata.color_encoding.color_space == .gray
	colors := if gray { 1 } else { 3 }
	if raw.channels.len != colors + file.metadata.extra_channels.len { return error('Invalid JPEG XL modular RGB channel count') }
	full := frame.size_upsampled()
	for c, channel in raw.channels {
		channel.validate()!
		factor := if c < colors { frame.upsampling } else { frame.extra_upsampling[c - colors] }
		if channel.width != int((full.width + factor - 1) / factor) || channel.height != int((full.height + factor - 1) / factor) {
			return error('Invalid JPEG XL modular RGB channel geometry')
		}
	}
	mut planes := [3]FloatPlane{}
	for c in 0 .. 3 {
		channel := raw.channels[if gray { 0 } else { c }]
		planes[c] = FloatPlane{ width: channel.width, height: channel.height,
			samples: modular_integer_plane_to_f32(channel.samples, 8, storage)! }
	}
	mut restored := restore_modular_frame(planes, frame_filter_geometry(frame))!
	if patches := raw.patches {
		restored = apply_frame_patches(restored, patches, patch_refs)!
	}
	return upsample_frame_planes(restored, frame, file.transform)
}
