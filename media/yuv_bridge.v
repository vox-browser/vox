// SPDX-License-Identifier: BSD-2-Clause
module main

import yuv

@[export: 'vox_yuv_u8_to_rgba']
fn native_yuv_u8_to_rgba(y &u8, y_stride u32, u &u8, u_stride u32, v &u8, v_stride u32, width u32, height u32, subsampling_x bool, subsampling_y bool, output &u8, stride u32, range u8, matrix u8) bool {
	return yuv.convert_native(y, y_stride, u, u_stride, v, v_stride, width, height,
		subsampling_x, subsampling_y, output, stride, range, matrix)
}

// libyuv's I420ToABGR and (unattenuated) I420AlphaToABGR for native video
// playback; a nil alpha plane makes the output opaque.
@[export: 'vox_i420_bt601_to_rgba']
fn native_i420_bt601_to_rgba(y &u8, y_stride i32, u &u8, u_stride i32, v &u8, v_stride i32, a &u8, a_stride i32, output &u8, stride i32, width i32, height i32) bool {
	return yuv.i420_bt601_to_rgba(y, int(y_stride), u, int(u_stride), v, int(v_stride), a,
		int(a_stride), output, int(stride), int(width), int(height))
}
