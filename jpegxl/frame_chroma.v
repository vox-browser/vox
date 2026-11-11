// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

// Source chroma interpolation precedes color restoration. Crop transform
// padding first so the last document sample supplies the replicated border.
fn expand_frame_chroma(input [3]FloatPlane, frame FrameHeader) ![3]FloatPlane {
	if frame.upsampling != 1 { return error('Chroma expansion requires coded frame geometry') }
	size := frame.size()
	if u64(size.width) * u64(size.height) > 67108864 / 3 { return error('JPEG XL chroma output sample budget exceeded') }
	mut output := [3]FloatPlane{}
	for c in 0 .. 3 {
		hs := frame.hshift(c)!
		vs := frame.vshift(c)!
		if hs > 1 || vs > 1 { return error('Unsupported JPEG XL chroma sampling factor') }
		width := (size.width + (u32(1) << hs) - 1) >> hs
		height := (size.height + (u32(1) << vs) - 1) >> vs
		mut plane := crop_float_plane(input[c], 0, 0, int(width), int(height))!
		if hs != 0 { plane = chroma_upsample_plane(plane, .horizontal)! }
		if vs != 0 { plane = chroma_upsample_plane(plane, .vertical)! }
		output[c] = plane
	}
	return output
}
