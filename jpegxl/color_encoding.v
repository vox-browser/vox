// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

pub enum ColorSpace {
	rgb
	gray
	xyb
	unknown
}

pub enum WhitePoint {
	d65          = 1
	custom       = 2
	equal_energy = 10
	dci          = 11
}

pub enum Primaries {
	srgb   = 1
	custom = 2
	bt2100 = 9
	p3     = 11
}

pub enum TransferFunction {
	bt709   = 1
	unknown = 2
	linear  = 8
	srgb    = 13
	pq      = 16
	dci     = 17
	hlg     = 18
}

pub enum RenderingIntent {
	perceptual
	relative
	saturation
	absolute
}

pub struct Chromaticity {
pub:
	x i32
	y i32
}

pub struct ColorEncoding {
pub:
	want_icc          bool
	color_space       ColorSpace = .rgb
	white_point       WhitePoint = .d65
	white             Chromaticity
	primaries         Primaries = .srgb
	custom_primaries  [3]Chromaticity
	have_gamma        bool
	gamma             u32              = 3333333
	transfer_function TransferFunction = .srgb
	rendering_intent  RenderingIntent  = .relative
}

fn (mut reader BitReader) read_enum_value(allowed []u32) !u32 {
	value := reader.read_u32([U32Code{}, U32Code{ offset: 1 }, U32Code{ bits: 4, offset: 2 },
		U32Code{ bits: 6, offset: 18 }]!)!
	if value !in allowed { return error('Invalid JPEG XL enum value') }
	return value
}

fn (mut reader BitReader) read_chromaticity() !Chromaticity {
	choices := [U32Code{ bits: 19 }, U32Code{ bits: 19, offset: 524288 },
		U32Code{ bits: 20, offset: 1048576 }, U32Code{ bits: 21, offset: 2097152 }]!
	x := unpack_signed(reader.read_u32(choices)!)
	y := unpack_signed(reader.read_u32(choices)!)
	return Chromaticity{ x: x, y: y }
}

fn white_xy(point WhitePoint, custom Chromaticity) (f32, f32) {
	return match point {
		.d65 { f32(0.3127), f32(0.3290) }
		.equal_energy { f32(1) / f32(3), f32(1) / f32(3) }
		.dci { f32(0.314), f32(0.351) }
		.custom { f32(custom.x) / f32(1000000), f32(custom.y) / f32(1000000) }
	}
}

fn validate_white(x f32, y f32, adaptation bool) ! {
	if x < 0 || x > 1 || y <= 0 || y > 1 { return error('Invalid JPEG XL white point') }
	wx := f64(x) / f64(y)
	wz := (1.0 - f64(x) - f64(y)) / f64(y)
	if !math.is_finite(wx) || !math.is_finite(wz) {
		return error('Invalid JPEG XL white point ratio')
	}
	if adaptation {
		matrix := [[f64(0.8951), 0.2664, -0.1614]!, [f64(-0.7502), 1.7135, 0.0367]!,
			[f64(0.0389), -0.0685, 1.0296]!]!
		target := [f64(0.96422), 1, 0.82521]!
		for row in matrix {
			source_lms := (f64(0) + row[0] * wx) + row[1] * 1.0 + row[2] * wz
			target_lms := (f64(0) + row[0] * target[0]) + row[1] * target[1] + row[2] * target[2]
			if source_lms == 0 || !math.is_finite(target_lms / source_lms) {
				return error('Invalid JPEG XL white adaptation')
			}
		}
	}
}

fn validate_primaries(points [3]Chromaticity, white_x f32, white_y f32) ! {
	validate_white(white_x, white_y, false)!
	mut matrix := [3][3]f64{}
	for i, point in points {
		x := f32(point.x) / f32(1000000)
		y := f32(point.y) / f32(1000000)
		matrix[0][i] = f64(x)
		matrix[1][i] = f64(y)
		matrix[2][i] = 1.0 - f64(x) - f64(y)
	}
	// First cofactor row, using the source's determinant summation order.
	first := matrix[1][1] * matrix[2][2] - matrix[1][2] * matrix[2][1]
	second := -(matrix[1][0] * matrix[2][2] - matrix[1][2] * matrix[2][0])
	third := matrix[1][0] * matrix[2][1] - matrix[1][1] * matrix[2][0]
	determinant := ((f64(0) + matrix[0][0] * first) + matrix[0][1] * second) + matrix[0][2] * third
	if math.abs(determinant) < 1e-12 { return error('Singular JPEG XL color primaries') }
}

pub fn (mut reader BitReader) read_color_encoding() !ColorEncoding {
	if reader.read(1)! != 0 { return ColorEncoding{} }
	want_icc := reader.read(1)! != 0
	space := reader.read_enum_value([u32(0), 1, 2, 3])!
	mut point := u32(1)
	if !want_icc && space != 2 { point = reader.read_enum_value([u32(1), 2, 10, 11])! }
	white := if point == 2 { reader.read_chromaticity()! } else { Chromaticity{} }
	mut primaries := u32(1)
	if !want_icc && space != 2 && space != 1 {
		primaries = reader.read_enum_value([u32(1), 2, 9, 11])!
	}
	mut custom := [3]Chromaticity{}
	if primaries == 2 {
		for i in 0 .. 3 { custom[i] = reader.read_chromaticity()! }
	}
	mut have_gamma := false
	mut gamma := u32(3333333)
	mut transfer := u32(13)
	mut intent := u32(1)
	if !want_icc {
		if space != 2 { have_gamma = reader.read(1)! != 0 }
		if have_gamma { gamma = u32(reader.read(24)!) }
		if !have_gamma && space != 2 {
			transfer = reader.read_enum_value([u32(1), 2, 8, 13, 16, 17, 18])!
		}
		if have_gamma {
			value := f32(gamma) * f32(0.0000001)
			if value > 1 || value * f32(8192) < 1 { return error('Invalid JPEG XL gamma') }
		}
		intent = reader.read_enum_value([u32(0), 1, 2, 3])!
	}
	if space == 2 || space == 3 || transfer == 2 { return error('Invalid JPEG XL color encoding') }
	white_point := unsafe { WhitePoint(point) }
	wx, wy := white_xy(white_point, white)
	if point == 2 { validate_white(wx, wy, true)! }
	if primaries == 2 { validate_primaries(custom, wx, wy)! }
	return ColorEncoding{
		want_icc:          want_icc
		color_space:       unsafe { ColorSpace(space) }
		white_point:       white_point
		white:             white
		primaries:         unsafe { Primaries(primaries) }
		custom_primaries:  custom
		have_gamma:        have_gamma
		gamma:             gamma
		transfer_function: unsafe { TransferFunction(transfer) }
		rendering_intent:  unsafe { RenderingIntent(intent) }
	}
}
