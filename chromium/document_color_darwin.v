// Copyright (c) 2018 Google Inc. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
// Scalar skcms adaptations: see licenses/skcms-BSD.txt.
module main

import math
import os
import platform

// Canonical D50 gamuts and sRGB transfer coefficients, matching SkNamedGamut
// and SkNamedTransferFn in Skia's include/core/SkColorSpace.h. These describe
// the rendering space; they are independent of any page or screenshot.
const document_srgb_d50 = [f32(0x6fa2) / 65536, f32(0x6299) / 65536, f32(0x24a0) / 65536,
	f32(0x38f5) / 65536, f32(0xb785) / 65536, f32(0x0f84) / 65536, f32(0x0390) / 65536,
	f32(0x18da) / 65536, f32(0xb6cf) / 65536]!
const document_p3_d50 = [f32(0.515102), 0.291965, 0.157153, 0.241182, 0.692236, 0.0665819, -0.00104941,
	0.0418818, 0.784378]!
const document_srgb_transfer = [f32(2.4), f32(1) / 1.055, f32(0.055) / 1.055, f32(1) / 12.92, 0.04045,
	0, 0]!
const document_p3_selected = os.getenv('VOX_DIAGNOSTIC_DOCUMENT_P3') == '1'

fn C.native_document_raster_uses_p3() i32

@[export: 'vox_document_display_p3_enabled']
fn document_display_p3_enabled() i32 {
	return i32(document_p3_selected)
}

// Scalar skcms PortableMath, rather than the NEON raster-pipeline variant.
// Keep each float operation separate: only the raster variant uses fused mad.
fn document_color_log2(x f32) f32 {
	bits := math.f32_bits(x)
	exponent := f32(bits) * (f32(1) / f32(1 << 23))
	mantissa := math.f32_from_bits((bits & 0x007fffff) | 0x3f000000)
	biased := exponent - f32(124.225514990)
	product := f32(1.498030302) * mantissa
	partial := biased - product
	correction := f32(1.725879990) / (f32(0.3520887068) + mantissa)
	return partial - correction
}

fn document_color_exp2(x f32) f32 {
	if x > 128 { return math.f32_from_bits(0x7f800000) }
	if x < -127 { return 0 }
	fraction := x - f32(math.floor(f64(x)))
	biased := x + f32(121.274057500)
	product := f32(1.490129070) * fraction
	partial := biased - product
	correction := f32(27.728023300) / (f32(4.84252568) - fraction)
	sum := partial + correction
	bits := f32(1 << 23) * sum
	if bits >= f32(2147483647) { return math.f32_from_bits(0x7f800000) }
	if bits < 0 { return 0 }
	return math.f32_from_bits(u32(bits))
}

fn document_color_power(x f32, y f32) f32 {
	if x <= 0 { return 0 }
	if x == 1 { return 1 }
	exponent := document_color_log2(x) * y
	return document_color_exp2(exponent)
}

fn document_color_parametric(value f32, tf [7]f32) f32 {
	sign := if value < 0 { f32(-1) } else { f32(1) }
	x := value * sign
	if x < tf[4] {
		product := tf[3] * x
		return sign * (product + tf[6])
	}
	product := tf[1] * x
	base := product + tf[2]
	curve := document_color_power(base, tf[0])
	return sign * (curve + tf[5])
}

fn document_color_inverse_transfer() [7]f32 {
	src := document_srgb_transfer
	mut inv := [7]f32{}
	product := src[3] * src[4]
	inv[4] = product + src[6]
	inv[3] = f32(1) / src[3]
	inv[6] = -src[6] / src[3]
	inv[0] = f32(1) / src[0]
	inv[1] = document_color_power(src[1], -src[0])
	inv[2] = -inv[1] * src[5]
	inv[5] = -src[2] / src[1]
	if inv[1] * inv[4] + inv[2] < 0 { inv[2] = -inv[1] * inv[4] }
	endpoint := document_color_parametric(1, src)
	base := inv[1] * endpoint
	inv[5] = f32(1) - document_color_power(base + inv[2], inv[0])
	return inv
}

const document_inverse_srgb_transfer = document_color_inverse_transfer()

// skcms_Matrix3x3_invert uses double intermediates, then stores floats.
fn document_color_inverse(m [9]f32) [9]f32 {
	a00, a01, a02 := f64(m[0]), f64(m[3]), f64(m[6])
	a10, a11, a12 := f64(m[1]), f64(m[4]), f64(m[7])
	a20, a21, a22 := f64(m[2]), f64(m[5]), f64(m[8])
	mut b0 := a00 * a11 - a01 * a10
	mut b1 := a00 * a12 - a02 * a10
	mut b2 := a01 * a12 - a02 * a11
	mut b3, mut b4, mut b5 := a20, a21, a22
	determinant := b0 * b5 - b1 * b4 + b2 * b3
	inverse := f64(1) / determinant
	b0 *= inverse
	b1 *= inverse
	b2 *= inverse
	b3 *= inverse
	b4 *= inverse
	b5 *= inverse
	return [f32(a11 * b5 - a12 * b4), f32(a12 * b3 - a10 * b5), f32(a10 * b4 - a11 * b3),
		f32(a02 * b4 - a01 * b5), f32(a00 * b5 - a02 * b3), f32(a01 * b3 - a00 * b4), f32(b2),
		f32(-b1), f32(b0)]!
}

fn document_color_gamut(source [9]f32, destination [9]f32) [9]f32 {
	inverse := document_color_inverse(destination)
	mut result := [9]f32{}
	for row in 0 .. 3 {
		for col in 0 .. 3 {
			red := inverse[row * 3] * source[col]
			green := inverse[row * 3 + 1] * source[3 + col]
			partial := red + green
			blue := inverse[row * 3 + 2] * source[6 + col]
			result[col * 3 + row] = partial + blue
		}
	}
	return result
}

const document_srgb_to_p3_gamut = document_color_gamut(document_srgb_d50, document_p3_d50)
const document_p3_to_srgb_gamut = document_color_gamut(document_p3_d50, document_srgb_d50)

fn document_color_transform(color [4]f32, gamut [9]f32) [4]f32 {
	linear := [document_color_parametric(color[0], document_srgb_transfer),
		document_color_parametric(color[1], document_srgb_transfer),
		document_color_parametric(color[2], document_srgb_transfer)]!
	mut result := color
	for row in 0 .. 3 {
		red := gamut[row] * linear[0]
		green := gamut[3 + row] * linear[1]
		partial := red + green
		blue := gamut[6 + row] * linear[2]
		result[row] = document_color_parametric(partial + blue, document_inverse_srgb_transfer)
	}
	return result
}

fn document_color_to_p3(color [4]f32) [4]f32 {
	mut result := document_color_transform(color, document_srgb_to_p3_gamut)
	if color[0] >= 0 && color[0] <= 1 && color[1] >= 0 && color[1] <= 1
		&& color[2] >= 0 && color[2] <= 1 {
		for channel in 0 .. 3 {
			result[channel] = math.max(f32(0), math.min(f32(1), result[channel]))
		}
	}
	return result
}

// Graphite keeps the transformed source in floating point through coverage
// and blending. A matrix/transfer approximation can put neutral ink slightly
// above one; clamping before coverage changes a later byte-rounding decision.
fn document_color_to_p3_for_blending(color [4]f32) [4]f32 {
	return document_color_transform(color, document_srgb_to_p3_gamut)
}

fn document_color_from_p3(color [4]f32) [4]f32 {
	return document_color_transform(color, document_p3_to_srgb_gamut)
}

// Compatibility image/gradient leaves still render in sRGB. Their opaque
// backdrop must be converted into that working space before rasterization.
@[export: 'vox_document_p3_to_srgb_pixels']
fn document_p3_to_srgb_pixels(pixels &u8, width i32, height i32, pitch i32) {
	if pixels == unsafe { nil } || width <= 0 || height <= 0
		|| int(pitch) < int(width) * 4 || int(width) * int(height) > 64 * 1024 * 1024 {
		return
	}
	unsafe {
		for y in 0 .. int(height) {
			for x in 0 .. int(width) {
				at := y * int(pitch) + x * 4
				alpha := f32(pixels[at + 3]) / 255
				if alpha == 0 { continue }
				color := document_color_from_p3([f32(pixels[at]) / 255 / alpha,
					f32(pixels[at + 1]) / 255 / alpha, f32(pixels[at + 2]) / 255 / alpha, alpha]!)
				for channel in 0 .. 3 {
					pixels[at + channel] = u8(math.floor(math.max(f32(0), math.min(f32(255), color[channel] * alpha * 255)) + 0.5))
				}
			}
		}
	}
}

@[export: 'vox_document_srgb_to_p3']
fn document_srgb_to_p3(color &f32) {
	if color == unsafe { nil } { return }
	value := unsafe { [color[0], color[1], color[2], color[3]]! }
	converted := document_color_to_p3(value)
	unsafe {
		for i in 0 .. 4 { color[i] = converted[i] }
	}
}

fn document_icc_u32(mut bytes []u8, at int, value u32) {
	for i in 0 .. 4 { bytes[at + i] = u8(value >> u32(24 - i * 8)) }
}

fn document_icc_signature(mut bytes []u8, at int, value string) {
	for i, byte in value.bytes() { bytes[at + i] = byte }
}

fn document_icc_mluc(text string) []u8 {
	mut bytes := []u8{len: 28 + text.len * 2}
	document_icc_signature(mut bytes, 0, 'mluc')
	document_icc_u32(mut bytes, 8, 1)
	document_icc_u32(mut bytes, 12, 12)
	document_icc_signature(mut bytes, 16, 'enUS')
	document_icc_u32(mut bytes, 20, u32(text.len * 2))
	document_icc_u32(mut bytes, 24, 28)
	for i, byte in text.bytes() { bytes[29 + i * 2] = byte }
	return bytes
}

fn document_display_p3_icc() []u8 {
	description := document_icc_mluc('Display P3')
	copyright := document_icc_mluc('Public colorimetric profile')
	description_at := 360
	copyright_at := (description_at + description.len + 3) & ~3
	mut bytes := []u8{len: (copyright_at + copyright.len + 3) & ~3}
	document_icc_u32(mut bytes, 0, u32(bytes.len))
	document_icc_u32(mut bytes, 8, 0x04300000)
	document_icc_signature(mut bytes, 12, 'mntrRGB XYZ ')
	bytes[24] = 7
	bytes[25] = 0xe4 // 2020-01-01, fixed profile creation date.
	bytes[27] = 1
	bytes[29] = 1
	document_icc_signature(mut bytes, 36, 'acsp')
	document_icc_u32(mut bytes, 64, 1)
	for i, value in [u32(0xf6d6), 0x10000, 0xd32d] {
		document_icc_u32(mut bytes, 68 + i * 4, value)
	}
	document_icc_signature(mut bytes, 80, 'vox ')
	document_icc_u32(mut bytes, 128, 9)
	names := ['rXYZ', 'gXYZ', 'bXYZ', 'wtpt', 'rTRC', 'gTRC', 'bTRC', 'desc', 'cprt']
	for index, name in names {
		offset := if index < 4 {
			240 + index * 20
		} else if index < 7 {
			320
		} else if index == 7 {
			description_at
		} else {
			copyright_at
		}
		size := if index < 4 {
			20
		} else if index < 7 {
			40
		} else if index == 7 {
			description.len
		} else {
			copyright.len
		}
		document_icc_signature(mut bytes, 132 + index * 12, name)
		document_icc_u32(mut bytes, 136 + index * 12, u32(offset))
		document_icc_u32(mut bytes, 140 + index * 12, u32(size))
	}
	for column in 0 .. 4 {
		at := 240 + column * 20
		document_icc_signature(mut bytes, at, 'XYZ ')
		for row in 0 .. 3 {
			value := if column < 3 {
				i32(math.round(f64(document_p3_d50[row * 3 + column]) * 65536))
			} else {
				[i32(0xf6d6), 0x10000, 0xd32d][row]
			}
			document_icc_u32(mut bytes, at + 8 + row * 4, u32(value))
		}
	}
	document_icc_signature(mut bytes, 320, 'para')
	bytes[329] = 4
	for i, value in document_srgb_transfer {
		document_icc_u32(mut bytes, 332 + i * 4, u32(i32(math.round(f64(value) * 65536))))
	}
	for i, value in description { bytes[description_at + i] = value }
	for i, value in copyright { bytes[copyright_at + i] = value }
	return bytes
}

__global document_p3_profile_bytes = []u8{}

@[export: 'vox_document_display_p3_profile']
fn document_display_p3_profile(size &i32) &u8 {
	if size == unsafe { nil } { return unsafe { nil } }
	unsafe { *size = 0 }
	if document_display_p3_enabled() == 0 { return unsafe { nil } }
	if document_p3_profile_bytes.len == 0 {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		document_p3_profile_bytes = document_display_p3_icc()
	}
	unsafe { *size = i32(document_p3_profile_bytes.len) }
	return document_p3_profile_bytes.data
}

fn document_p3_shape(shape C.VoxGraphiteShape) C.VoxGraphiteShape {
	mut result := shape
	if C.native_document_raster_uses_p3() == 0 { return result }
	color := if shape.has_float_color != 0 {
		shape.float_color
	} else {
		[f32(shape.red) / 255, f32(shape.green) / 255, f32(shape.blue) / 255, f32(shape.alpha) / 255]!
	}
	result.float_color = document_color_to_p3(color)
	result.has_float_color = 1
	if shape.has_underlay != 0 {
		underlay := if shape.has_float_underlay_color != 0 {
			shape.underlay_float_color
		} else {
			[f32(shape.underlay_rgba[0]) / 255, f32(shape.underlay_rgba[1]) / 255,
				f32(shape.underlay_rgba[2]) / 255, f32(shape.underlay_rgba[3]) / 255]!
		}
		result.underlay_float_color = document_color_to_p3(underlay)
		result.has_float_underlay_color = 1
	}
	return result
}

@[export: 'vox_document_paths_use_p3']
fn document_paths_use_p3(paths &C.VoxGraphitePath, count i32) i32 {
	if C.native_document_raster_uses_p3() == 0 || paths == unsafe { nil } || count <= 0 || count > 65536 {
		return 0
	}
	for i in 0 .. int(count) { if unsafe { paths[i].gradient } != 0 { return 0 } }
	return 1
}

fn document_p3_path(path C.VoxGraphitePath) C.VoxGraphitePath {
	mut result := path
	color := if path.has_float_color != 0 {
		path.float_color
	} else {
		[f32(path.red) / 255, f32(path.green) / 255, f32(path.blue) / 255, f32(path.alpha) / 255]!
	}
	result.float_color = document_color_to_p3(color)
	result.has_float_color = 1
	return result
}
