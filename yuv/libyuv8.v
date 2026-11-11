module yuv

// libyuv's 8-bit YUV matrices (row_common.cc). Each converts limited- or
// full-range samples with 6-bit chroma coefficients, a Y scale applied to the
// byte replicated into 16 bits, and a rounding bias.
pub enum LibyuvMatrix {
	bt601_limited  // kYuvI601Constants
	bt601_full     // kYuvJPEGConstants
	bt709_limited  // kYuvH709Constants
	bt709_full     // kYuvF709Constants
	bt2020_limited // kYuv2020Constants
	bt2020_full    // kYuvV2020Constants
}

// Plane layouts libavif hands to libyuv for 8-bit images.
pub enum LibyuvLayout {
	yuv444
	yuv422
	yuv420
	yuv400
}

struct LibyuvConstants {
	y_scale u32
	y_bias  int
	u_to_b  int
	u_to_g  int
	v_to_g  int
	v_to_r  int
}

fn libyuv_constants(matrix LibyuvMatrix) LibyuvConstants {
	return match matrix {
		.bt601_limited { LibyuvConstants{18997, -1160, 128, 25, 52, 102} }
		.bt601_full { LibyuvConstants{16320, 32, 113, 22, 46, 90} }
		.bt709_limited { LibyuvConstants{18997, -1160, 128, 14, 34, 115} }
		.bt709_full { LibyuvConstants{16320, 32, 119, 12, 30, 101} }
		.bt2020_limited { LibyuvConstants{19003, -1160, 128, 12, 42, 107} }
		.bt2020_full { LibyuvConstants{16320, 32, 120, 11, 37, 94} }
	}
}

@[inline]
fn libyuv_pixel(c LibyuvConstants, y u8, u u8, v u8, out &u8) {
	luma := int((u32(y) * 0x0101 * c.y_scale) >> 16) + c.y_bias
	cb := int(u) - 128
	cr := int(v) - 128
	unsafe {
		out[0] = libyuv_clamp(luma + cr * c.v_to_r)
		out[1] = libyuv_clamp(luma - cb * c.u_to_g - cr * c.v_to_g)
		out[2] = libyuv_clamp(luma + cb * c.u_to_b)
		out[3] = 255
	}
}

// ScaleRowUp2_Linear_Any_C: horizontal 2x chroma upsampling with 3:1 weights,
// copying the first and last samples.
@[direct_array_access]
fn libyuv_up2_linear(src &u8, mut dst []u8, width int) {
	unsafe {
		dst[0] = src[0]
		work := (width - 1) & ~1
		for x in 0 .. work / 2 {
			a := int(src[x])
			b := int(src[x + 1])
			dst[1 + 2 * x] = u8((a * 3 + b + 2) >> 2)
			dst[2 + 2 * x] = u8((a + b * 3 + 2) >> 2)
		}
		dst[width - 1] = src[(width - 1) / 2]
	}
}

// ScaleRowUp2_Bilinear_Any_C: two output rows between chroma rows s and t
// with 9:3:3:1 weights, and 3:1 vertical weights at the first and last columns.
@[direct_array_access]
fn libyuv_up2_bilinear(s &u8, t &u8, mut upper []u8, mut lower []u8, width int) {
	unsafe {
		upper[0] = u8((3 * int(s[0]) + int(t[0]) + 2) >> 2)
		lower[0] = u8((int(s[0]) + 3 * int(t[0]) + 2) >> 2)
		work := (width - 1) & ~1
		for x in 0 .. work / 2 {
			s0 := int(s[x])
			s1 := int(s[x + 1])
			t0 := int(t[x])
			t1 := int(t[x + 1])
			upper[1 + 2 * x] = u8((s0 * 9 + s1 * 3 + t0 * 3 + t1 + 8) >> 4)
			upper[2 + 2 * x] = u8((s0 * 3 + s1 * 9 + t0 + t1 * 3 + 8) >> 4)
			lower[1 + 2 * x] = u8((s0 * 3 + s1 + t0 * 9 + t1 * 3 + 8) >> 4)
			lower[2 + 2 * x] = u8((s0 + s1 * 3 + t0 * 3 + t1 * 9 + 8) >> 4)
		}
		last := (width - 1) / 2
		upper[width - 1] = u8((3 * int(s[last]) + int(t[last]) + 2) >> 2)
		lower[width - 1] = u8((int(s[last]) + 3 * int(t[last]) + 2) >> 2)
	}
}

@[direct_array_access]
fn libyuv_row(c LibyuvConstants, y &u8, u &u8, v &u8, out &u8, width int) {
	for x in 0 .. width {
		unsafe { libyuv_pixel(c, y[x], u[x], v[x], out + x * 4) }
	}
}

// libyuv_to_rgba converts 8-bit YUV planes to R, G, B, A bytes exactly as
// libavif's libyuv path does for an AVIF_RGB_FORMAT_RGBA destination:
// I444ToABGRMatrix, I422ToABGRMatrix(Filter), I420ToABGRMatrix(Filter) and
// I400ToARGBMatrix. `bilinear` selects libyuv's kFilterBilinear chroma
// upsampling (libavif's default); otherwise each chroma sample is repeated.
@[direct_array_access]
pub fn libyuv_to_rgba(y &u8, y_stride int, u &u8, u_stride int, v &u8, v_stride int, output &u8, stride int, width int, height int, layout LibyuvLayout, matrix LibyuvMatrix, bilinear bool) bool {
	if isnil(y) || isnil(output) || width <= 0 || height <= 0 || stride < width * 4
		|| (layout != .yuv400 && (isnil(u) || isnil(v))) {
		return false
	}
	c := libyuv_constants(matrix)
	match layout {
		.yuv400 {
			for row in 0 .. height {
				for x in 0 .. width {
					unsafe { libyuv_pixel(c, (y + row * y_stride)[x], 128, 128, output + row * stride + x * 4) }
				}
			}
		}
		.yuv444 {
			for row in 0 .. height {
				unsafe {
					libyuv_row(c, y + row * y_stride, u + row * u_stride, v + row * v_stride,
						output + row * stride, width)
				}
			}
		}
		.yuv422, .yuv420 {
			if !bilinear {
				for row in 0 .. height {
					chroma_row := if layout == .yuv420 { row >> 1 } else { row }
					unsafe {
						y_row := y + row * y_stride
						u_row := u + chroma_row * u_stride
						v_row := v + chroma_row * v_stride
						for x in 0 .. width {
							libyuv_pixel(c, y_row[x], u_row[x >> 1], v_row[x >> 1], output + row * stride +
								x * 4)
						}
					}
				}
				return true
			}
			mut u_upper := []u8{len: width}
			mut v_upper := []u8{len: width}
			if layout == .yuv422 {
				for row in 0 .. height {
					unsafe {
						libyuv_up2_linear(u + row * u_stride, mut u_upper, width)
						libyuv_up2_linear(v + row * v_stride, mut v_upper, width)
						libyuv_row(c, y + row * y_stride, u_upper.data, v_upper.data, output + row * stride,
							width)
					}
				}
				return true
			}
			// I420ToARGBMatrixBilinear: the first and (for an even height) last
			// luma rows use their chroma row alone; each pair between blends two.
			mut u_lower := []u8{len: width}
			mut v_lower := []u8{len: width}
			unsafe {
				libyuv_up2_linear(u, mut u_upper, width)
				libyuv_up2_linear(v, mut v_upper, width)
				libyuv_row(c, y, u_upper.data, v_upper.data, output, width)
				mut chroma := 0
				mut row := 1
				for pair := 0; pair < height - 2; pair += 2 {
					libyuv_up2_bilinear(u + chroma * u_stride, u + (chroma + 1) * u_stride, mut u_upper, mut
						u_lower, width)
					libyuv_up2_bilinear(v + chroma * v_stride, v + (chroma + 1) * v_stride, mut v_upper, mut
						v_lower, width)
					libyuv_row(c, y + row * y_stride, u_upper.data, v_upper.data, output + row * stride, width)
					libyuv_row(c, y + (row + 1) * y_stride, u_lower.data, v_lower.data, output + (row + 1) * stride,
						width)
					row += 2
					chroma++
				}
				if height & 1 == 0 {
					libyuv_up2_linear(u + chroma * u_stride, mut u_upper, width)
					libyuv_up2_linear(v + chroma * v_stride, mut v_upper, width)
					libyuv_row(c, y + row * y_stride, u_upper.data, v_upper.data, output + row * stride, width)
				}
			}
		}
	}
	return true
}

// libyuv_packed_to_rgba converts tightly packed Y, U and V planes (the
// layout native_avif.c's vox_avif_decode_planes returns, with libavif's
// layout and matrix numbering) to RGBA rows of width * 4 bytes, using
// bilinear chroma upsampling. It returns none for an inconsistent size.
pub fn libyuv_packed_to_rgba(planes &u8, size int, width int, height int, layout int, matrix int) ?[]u8 {
	if isnil(planes) || width <= 0 || height <= 0 || layout < 0 || layout > 3 || matrix < 0
		|| matrix > 5 {
		return none
	}
	plane_layout := unsafe { LibyuvLayout(layout) }
	chroma_width := if plane_layout == .yuv444 { width } else { (width + 1) / 2 }
	chroma_height := if plane_layout == .yuv420 { (height + 1) / 2 } else { height }
	chroma_size := if plane_layout == .yuv400 { 0 } else { chroma_width * chroma_height }
	if i64(size) != i64(width) * height + 2 * i64(chroma_size) {
		return none
	}
	mut pixels := []u8{len: width * height * 4}
	u_plane := unsafe { planes + width * height }
	v_plane := unsafe { u_plane + chroma_size }
	if !libyuv_to_rgba(planes, width, u_plane, chroma_width, v_plane, chroma_width, pixels.data,
		width * 4, width, height, plane_layout, unsafe { LibyuvMatrix(matrix) }, true) {
		return none
	}
	return pixels
}
