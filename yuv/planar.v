// Copyright (c) Radzivon Bartoshyk, 2024. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
// Translation of yuv 0.8.17's 8-bit planar conversion. See LICENSE.
module yuv

pub enum Range as u8 {
	limited
	full
}

pub enum Matrix as u8 {
	bt709
	fcc
	bt470bg
	bt601
	smpte240
	bt2020
}

pub enum Sampling as u8 {
	yuv420
	yuv422
	yuv444
}

// Preserve the former decoder's integer quantization independently of CPU
// instructions. The browser used NEON RDM on Apple Silicon; scalar conversion
// rounds once after summing the three channel contributions.
pub enum Rounding as u8 {
	scalar
	neon
	neon_rdm
	x86
}

pub struct PlanarImage {
pub:
	y        []u8
	u        []u8
	v        []u8
	y_stride int
	u_stride int
	v_stride int
	width    int
	height   int
	sampling Sampling
}

struct Transform {
	y  int
	cr int
	cb int
	g1 int
	g2 int
}

fn inverse_transform(range Range, matrix Matrix) Transform {
	// Source's precomputed 13-bit coefficients, including its SMPTE240 values.
	// FCC uses the source f32 calculation rounded to 13 fractional bits.
	if range == .full {
		return match matrix {
			.bt709 { Transform{8192, 12901, 15201, 3835, 1535} }
			.fcc { Transform{8192, 11469, 14582, 5832, 2719} }
			.bt470bg { Transform{8192, 12747, 15216, 4004, 1535} }
			.bt601 { Transform{8192, 11485, 14516, 5850, 2819} }
			.smpte240 { Transform{8192, 14959, 12911, 1856, 3904} }
			.bt2020 { Transform{8192, 12080, 15412, 4681, 1348} }
		}
	}
	return match matrix {
		.bt709 { Transform{9539, 14686, 17305, 4366, 1747} }
		.fcc { Transform{9539, 13056, 16600, 6639, 3095} }
		.bt470bg { Transform{9539, 14511, 17322, 4558, 1748} }
		.bt601 { Transform{9539, 13075, 16525, 6660, 3209} }
		.smpte240 { Transform{9539, 17029, 14697, 2113, 4445} }
		.bt2020 { Transform{9539, 13752, 17545, 5328, 1535} }
	}
}

fn plane_fits(length int, stride int, width int, height int) bool {
	// Division checks the last active row without overflowing stride * height.
	return width > 0 && height > 0 && stride >= width && length >= width
		&& height - 1 <= (length - width) / stride
}

@[inline]
fn clamp_byte(value int) u8 {
	return u8(if value < 0 {
		0
	} else if value > 255 {
		255
	} else {
		value
	})
}

// to_rgba writes opaque, top-down RGBA, leaving destination row padding intact.
// All views are checked before the first write, including independent U/V strides
// and the ceil-divided chroma dimensions for odd-sized frames.
pub fn (image &PlanarImage) to_rgba(mut output []u8, stride int, range Range, matrix Matrix, rounding Rounding) ! {
	if image.width <= 0 || image.width > max_int / 4 || image.height <= 0
		|| int(image.sampling) > 2 || int(range) > 1 || int(matrix) > 5
		|| int(rounding) > 3 {
		return error('Invalid YUV conversion parameters')
	}
	x_shift := if image.sampling == .yuv444 { 0 } else { 1 }
	y_shift := if image.sampling == .yuv420 { 1 } else { 0 }
	chroma_width := (image.width >> x_shift) + (image.width & x_shift)
	chroma_height := (image.height >> y_shift) + (image.height & y_shift)
	if !plane_fits(image.y.len, image.y_stride, image.width, image.height)
		|| !plane_fits(image.u.len, image.u_stride, chroma_width, chroma_height)
		|| !plane_fits(image.v.len, image.v_stride, chroma_width, chroma_height)
		|| !plane_fits(output.len, stride, image.width * 4, image.height) {
		return error('YUV plane or RGBA destination is too short')
	}
	t := inverse_transform(range, matrix)
	bias := if range == .limited { 16 } else { 0 }
	for row in 0 .. image.height {
		y_offset := row * image.y_stride
		u_offset := (row >> y_shift) * image.u_stride
		v_offset := (row >> y_shift) * image.v_stride
		dst_offset := row * stride
		for column in 0 .. image.width {
			luma := int(image.y[y_offset + column]) - bias
			cb := int(image.u[u_offset + (column >> x_shift)]) - 128
			cr := int(image.v[v_offset + (column >> x_shift)]) - 128
			mut r := 0
			mut g := 0
			mut b := 0
			if rounding == .scalar {
				y := luma * t.y
				r = (y + cr * t.cr + 4096) >> 13
				g = (y - cr * t.g1 - cb * t.g2 + 4096) >> 13
				b = (y + cb * t.cb + 4096) >> 13
			} else {
				// Emulate saturating luma subtraction and the source's widening
				// and multiply-high operations with ordinary integer arithmetic.
				y8 := if luma < 0 { 0 } else { luma }
				round := if rounding == .neon { 0 } else { 16384 }
				if rounding == .x86 {
					y := (((y8 * 257) >> 6) * t.y + round) >> 15
					u := ((cb + 128) * 257 >> 6) - 514
					v := ((cr + 128) * 257 >> 6) - 514
					r = y + ((v * t.cr + round) >> 15)
					b = y + ((u * t.cb + round) >> 15)
					g = y - ((v * t.g1 + round) >> 15) - ((u * t.g2 + round) >> 15)
				} else {
					y := ((((y8 * 257 + 32) >> 6) * t.y) + round) >> 15
					r = y + ((cr * 4 * t.cr + round) >> 15)
					b = y + ((cb * 4 * t.cb + round) >> 15)
					if image.sampling == .yuv420 && row < image.height - image.height % 2 {
						// The two-row kernel rounds positive green coefficients
						// before subtraction; its unpaired last row uses negatives.
						g = y - ((cr * 4 * t.g1 + round) >> 15) - ((cb * 4 * t.g2 + round) >> 15)
					} else {
						g = y + ((-cr * 4 * t.g1 + round) >> 15) + ((-cb * 4 * t.g2 + round) >> 15)
					}
				}
			}
			dst := dst_offset + column * 4
			output[dst] = clamp_byte(r)
			output[dst + 1] = clamp_byte(g)
			output[dst + 2] = clamp_byte(b)
			output[dst + 3] = 255
		}
	}
}
