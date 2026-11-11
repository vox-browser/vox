// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct FloatPlane {
pub:
	width   int
	height  int
	samples []f32
}

fn (plane FloatPlane) validate() ! {
	if modular_sample_count(plane.width, plane.height)! != plane.samples.len {
		return error('Invalid JPEG XL floating-point plane shape')
	}
}

@[direct_array_access]
fn (plane FloatPlane) at_border(x int, y int) f32 {
	px := if x < 0 {
		0
	} else if x >= plane.width {
		plane.width - 1
	} else {
		x
	}
	py := if y < 0 {
		0
	} else if y >= plane.height {
		plane.height - 1
	} else {
		y
	}
	return plane.samples[py * plane.width + px]
}

// Whether every value is finite. An f32 is infinite or NaN exactly when its
// exponent bits are all set, as math.is_finite finds after widening; the
// branch-free test over the bits vectorizes.
@[direct_array_access]
fn all_finite(values []f32) bool {
	data := unsafe { &u32(values.data) }
	mut nonfinite := u32(0)
	for i in 0 .. values.len {
		nonfinite |= u32((unsafe { data[i] } & 0x7f800000) == 0x7f800000)
	}
	return nonfinite == 0
}

// Copies a width x height rectangle of samples from src, whose rows start
// src_stride apart from src_start, into dst at dst_start with rows dst_stride
// apart. Both rectangles must lie inside their arrays.
@[direct_array_access]
fn copy_float_rect(mut dst []f32, dst_start int, dst_stride int, src []f32, src_start int, src_stride int, width int, height int) ! {
	if width < 0 || height < 0 { return error('Invalid JPEG XL plane copy') }
	if width == 0 || height == 0 { return }
	if dst_start < 0 || src_start < 0 || dst_stride < width || src_stride < width
		|| i64(dst_start) + i64(height - 1) * dst_stride + width > dst.len
		|| i64(src_start) + i64(height - 1) * src_stride + width > src.len {
		return error('Invalid JPEG XL plane copy')
	}
	for y in 0 .. height {
		unsafe {
			vmemcpy(&f32(dst.data) + dst_start + y * dst_stride, &f32(src.data) + src_start + y * src_stride,
				width * int(sizeof(f32)))
		}
	}
}
