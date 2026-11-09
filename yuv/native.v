// SPDX-License-Identifier: BSD-2-Clause
module yuv

// convert_native is the browser's C ABI boundary. Native decoders own the
// readable stride * height buffers and the disjoint writable RGBA buffer.
// Reject invalid metadata before constructing borrowed V views. No allocation
// or ownership crosses the boundary.
pub fn convert_native(y &u8, y_stride u32, u &u8, u_stride u32, v &u8, v_stride u32, width u32, height u32, subsampling_x bool, subsampling_y bool, output &u8, stride u32, range u8, matrix u8) bool {
	if isnil(y) || isnil(u) || isnil(v) || isnil(output) || width == 0 || height == 0
		|| width > 0x1fffffff || height > 0x7fffffff || y_stride > 0x7fffffff
		|| u_stride > 0x7fffffff || v_stride > 0x7fffffff || stride > 0x7fffffff
		|| range > 1 || matrix > 5 || (!subsampling_x && subsampling_y) {
		return false
	}
	ch := if subsampling_y { (u64(height) + 1) / 2 } else { u64(height) }
	y_len := u64(y_stride) * height
	u_len := u64(u_stride) * ch
	v_len := u64(v_stride) * ch
	dst_len := u64(stride) * height
	if y_len > u64(max_int) || u_len > u64(max_int) || v_len > u64(max_int)
		|| dst_len > u64(max_int) {
		return false
	}
	image := PlanarImage{
		y:        unsafe { y.vbytes(int(y_len)) }
		u:        unsafe { u.vbytes(int(u_len)) }
		v:        unsafe { v.vbytes(int(v_len)) }
		y_stride: int(y_stride)
		u_stride: int(u_stride)
		v_stride: int(v_stride)
		width:    int(width)
		height:   int(height)
		sampling: if subsampling_y {
			.yuv420
		} else if subsampling_x {
			.yuv422
		} else {
			.yuv444
		}
	}
	mut destination := unsafe { output.vbytes(int(dst_len)) }
	mut rounding := Rounding.scalar
	$if arm64 {
		// Apple Silicon's previous yuv 0.8.17 path used NEON RDM.
		rounding = .neon_rdm
	}
	$if amd64 || i386 {
		rounding = .x86
	}
	image.to_rgba(mut destination, int(stride), unsafe { Range(range) }, unsafe { Matrix(matrix) }, rounding) or { return false }
	return true
}
