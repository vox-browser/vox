// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

fn validate_modular_xyb_frame(file FileHeader, frame FrameHeader) ! {
	validate_modular_xyb_frame_alpha(file, frame, false)!
}

fn validate_modular_xyb_frame_alpha(file FileHeader, frame FrameHeader, allow_alpha bool) ! {
	validate_modular_group_geometry(frame)!
	if frame.encoding != .modular || !file.metadata.xyb_encoded
		|| file.metadata.extra_channels.len > 1 || (!allow_alpha && file.metadata.extra_channels.len != 0)
		|| frame.extra_upsampling.len != file.metadata.extra_channels.len || !frame.is444() || frame.has_lf_frame()
		|| frame.has_patches() || frame.has_splines() || frame.has_noise() || frame.do_ycbcr {
		return error('Unsupported JPEG XL modular XYB rendering services')
	}
	for i, extra in file.metadata.extra_channels {
		if extra.kind != .alpha || extra.dimension_shift != 0 || extra.bit_depth.floating_point
			|| extra.bit_depth.bits_per_sample != 8 || frame.extra_upsampling[i] !in [u32(1), 2, 4, 8]
			|| frame.extra_upsampling[i] < frame.upsampling {
			return error('JPEG XL modular XYB requires one supported 8-bit alpha channel')
		}
	}
	size := frame.size()
	if u64(size.width)*u64(size.height) > 67108864 / u64(3 + file.metadata.extra_channels.len) {
		return error('Invalid JPEG XL modular XYB frame planes')
	}
}

// Render opaque modular XYB planes in source color space, before the final
// color conversion. LF saving and visible output share this stage ordering.
pub fn render_modular_xyb_frame(raw ModularFramePlanes, file FileHeader, frame FrameHeader, storage ModularStorage) ![3]FloatPlane {
	return render_modular_xyb_frame_impl(raw, file, frame, storage, false)
}

fn render_modular_xyb_frame_impl(raw ModularFramePlanes, file FileHeader, frame FrameHeader, storage ModularStorage, allow_alpha bool) ![3]FloatPlane {
	validate_modular_xyb_frame_alpha(file, frame, allow_alpha)!
	if raw.channels.len != 3 + file.metadata.extra_channels.len { return error('Invalid JPEG XL modular XYB channel count') }
	for c, channel in raw.channels {
		channel.validate()!
		factor := if c < 3 { frame.upsampling } else { frame.extra_upsampling[c - 3] }
		full := frame.size_upsampled()
		width := (full.width + factor - 1) / factor
		height := (full.height + factor - 1) / factor
		if channel.width != int(width) || channel.height != int(height) {
			return error('Incorrect JPEG XL modular XYB frame geometry')
		}
	}
	planes := modular_xyb_planes(raw.channels[..3], raw.quantization, storage)!
	restored := restore_modular_frame(planes, frame_filter_geometry(frame))!
	return upsample_frame_planes(restored, frame, file.transform)
}
