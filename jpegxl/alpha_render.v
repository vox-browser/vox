// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

// Extra channels are normalized before their own upsampling stage. Color
// restoration never filters alpha, and premultiplication belongs to final output.
fn render_alpha_plane(channel ModularChannel, file FileHeader, frame FrameHeader, storage ModularStorage) !FloatPlane {
	validate_modular_group_geometry(frame)!
	channel.validate()!
	if file.metadata.extra_channels.len != 1 || frame.extra_upsampling.len != 1 {
		return error('JPEG XL alpha rendering requires one channel')
	}
	extra := file.metadata.extra_channels[0]
	factor := frame.extra_upsampling[0]
	if extra.kind != .alpha || extra.dimension_shift != 0 || extra.bit_depth.floating_point
		|| extra.bit_depth.bits_per_sample != 8 || factor !in [u32(1), 2, 4, 8] || factor < frame.upsampling {
		return error('Unsupported JPEG XL alpha rendering services')
	}
	size := frame.size_upsampled()
	if u64(size.width) * u64(size.height) > 67108864 / 4
		|| channel.width != int((size.width + factor - 1) / factor)
		|| channel.height != int((size.height + factor - 1) / factor) {
		return error('Invalid JPEG XL alpha rendering geometry')
	}
	samples := modular_integer_plane_to_f32(channel.samples, 8, storage)!
	plane := FloatPlane{ width: channel.width, height: channel.height, samples: samples }
	if factor == 1 { return plane }
	weights := match factor {
		2 { file.transform.weights2[..] }
		4 { file.transform.weights4[..] }
		8 { file.transform.weights8[..] }
		else { return error('Invalid JPEG XL alpha upsampling factor') }
	}
	return upsample_plane(plane, int(factor), weights, int(size.width), int(size.height))
}
