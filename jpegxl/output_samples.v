// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

// The original 32x32 blue-noise ranks are attributed in DITHER_NOTICE.md.
const output_dither_ranks = $embed_file('data/dither_32x32.bin')

pub fn modular_integer_row_to_f32(input []i32, bits u32, storage ModularStorage) ![]f32 {
	if bits == 0 || bits > 31 || input.len > 1048576 {
		return error('Invalid JPEG XL integer output row')
	}
	scale := f32(1) / f32((u64(1) << bits) - 1)
	mut result := []f32{len: input.len}
	for i, value in input {
		result[i] = f32(if storage == .signed16 { i32(i16(value)) } else { value }) * scale
	}
	return result
}

// Whole channels use the frame sample budget rather than the row limit; each
// sample is converted exactly as modular_integer_row_to_f32 does.
pub fn modular_integer_plane_to_f32(input []i32, bits u32, storage ModularStorage) ![]f32 {
	if bits == 0 || bits > 31 || input.len > 67108864 {
		return error('Invalid JPEG XL integer output plane')
	}
	scale := f32(1) / f32((u64(1) << bits) - 1)
	mut result := []f32{len: input.len}
	for i, value in input {
		result[i] = f32(if storage == .signed16 { i32(i16(value)) } else { value }) * scale
	}
	return result
}

pub fn premultiply_output_row(color []f32, alpha []f32) ![]f32 {
	if color.len != alpha.len || color.len > 1048576 {
		return error('Invalid JPEG XL premultiplied output row')
	}
	mut result := []f32{len: color.len}
	for i, value in color { result[i] = value * alpha[i] }
	return result
}

// Matches native SIMD round-to-nearest-even after the source's positional
// dither. Scalar source fallback uses ties-away; that fallback is not this API.
pub fn quantize_output_row(input []f32, x u32, y u32, channel u32, bits u32) ![]u8 {
	mut result := []u8{len: input.len}
	quantize_output_row_into(input, x, y, channel, bits, mut result)!
	return result
}

fn C.rintf(f32) f32

// quantize_output_row into the first input.len bytes of `out`. In-range values
// round half to even with rintf, which is the default IEEE rounding the
// source's SIMD path uses; NaN and nonpositive values become 0. The loop has
// no early exits so it vectorizes.
@[direct_array_access]
fn quantize_output_row_into(input []f32, x u32, y u32, channel u32, bits u32, mut out []u8) ! {
	if bits == 0 || bits > 8 || input.len > 1048576 || out.len < input.len {
		return error('Invalid JPEG XL quantized output row')
	}
	maximum := f32((u32(1) << bits) - 1)
	ranks := output_dither_ranks.data()
	row := int((u64(y) + u64(channel) * 13) % 32) * 32
	first := int((u64(x) + u64(channel) * 23) % 32)
	for i in 0 .. input.len {
		column := (first + i) & 31
		dither := (f32(2) * f32(unsafe { ranks[row + column] }) - f32(255)) / f32(512)
		scaled := input[i] * maximum
		dithered := scaled + dither
		rounded := C.rintf(dithered)
		out[i] = if dithered > 0 {
			if dithered >= maximum { u8(maximum) } else { u8(rounded) }
		} else {
			u8(0)
		}
	}
}
