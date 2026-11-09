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
