// SPDX-License-Identifier: BSD-2-Clause
module main

import yuv

@[export: 'vox_yuv_u8_to_rgba']
fn native_yuv_u8_to_rgba(y &u8, y_stride u32, u &u8, u_stride u32, v &u8, v_stride u32, width u32, height u32, subsampling_x bool, subsampling_y bool, output &u8, stride u32, range u8, matrix u8) bool {
	return yuv.convert_native(y, y_stride, u, u_stride, v, v_stride, width, height,
		subsampling_x, subsampling_y, output, stride, range, matrix)
}
