// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

// Render opaque modular XYB planes in source color space, before the final
// color conversion. LF saving and visible output share this stage ordering.
pub fn render_modular_xyb_frame(raw ModularFramePlanes, file FileHeader, frame FrameHeader, storage ModularStorage) ![3]FloatPlane {
	validate_modular_group_geometry(frame)!
	if frame.encoding != .modular || !file.metadata.xyb_encoded || file.metadata.extra_channels.len != 0
		|| frame.extra_upsampling.len != 0 || !frame.is444() || frame.has_lf_frame()
		|| frame.has_patches() || frame.has_splines() || frame.has_noise() || frame.do_ycbcr {
		return error('Unsupported JPEG XL modular XYB rendering services')
	}
	size := frame.size()
	if raw.channels.len != 3 || u64(size.width)*u64(size.height) > 67108864 / 3 {
		return error('Invalid JPEG XL modular XYB frame planes')
	}
	for channel in raw.channels {
		if channel.width != int(size.width) || channel.height != int(size.height) {
			return error('Incorrect JPEG XL modular XYB frame geometry')
		}
	}
	planes := modular_xyb_planes(raw.channels, raw.quantization, storage)!
	restored := restore_modular_frame(planes, frame_filter_geometry(frame))!
	return upsample_frame_planes(restored, frame, file.transform)
}
