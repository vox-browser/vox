// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

// Filtering is performed at coded resolution before image upsampling.
fn frame_filter_geometry(frame FrameHeader) FrameHeader {
	size := frame.size()
	return FrameHeader{ ...frame, width: size.width, height: size.height, lf_level: 0, upsampling: 1 }
}

fn upsample_frame_planes(input [3]FloatPlane, frame FrameHeader, transform CustomTransformData) ![3]FloatPlane {
	if frame.upsampling == 1 { return input }
	weights := match frame.upsampling {
		2 { transform.weights2[..] }
		4 { transform.weights4[..] }
		8 { transform.weights8[..] }
		else { return error('Invalid JPEG XL frame upsampling factor') }
	}
	size := frame.size_upsampled()
	if u64(size.width) * u64(size.height) > 67108864 / 3 { return error('JPEG XL frame upsampling sample budget exceeded') }
	mut output := [3]FloatPlane{}
	for c in 0 .. 3 { output[c] = upsample_plane(input[c], int(frame.upsampling), weights, int(size.width), int(size.height))! }
	return output
}

fn render_vardct_frame(raw VarDctFramePlanes, frame FrameHeader, transform CustomTransformData) ![3]FloatPlane {
	restored := restore_vardct_frame(raw, frame_filter_geometry(frame))!
	return upsample_frame_planes(restored, frame, transform)
}
