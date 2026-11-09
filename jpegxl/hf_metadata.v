// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct HfMetadata {
pub:
	width         int
	height        int
	colors        HfGroupColorMap
	raw_quant     []i32
	transform_ids []u8
	sharpness     []u8
}

// Reconstruct one LF group's maps from decoded modular channels. The first two
// planes are color tiles; the third has transform IDs and quantization rows;
// the fourth contains sharpness for every block. Unused trailing transform
// records are permitted, matching the source.
pub fn reconstruct_hf_metadata(input []ModularChannel, width int, height int, count int, is444 bool, storage ModularStorage) !HfMetadata {
	if width < 1 || width > 256 || height < 1 || height > 256 || count < 1 || count > 65536 || input.len != 4 {
		return error('Invalid JPEG XL HF metadata dimensions')
	}
	cw := (width + 7) / 8
	ch := (height + 7) / 8
	for i, plane in input {
		plane.validate()!
		w := if i < 2 { cw } else if i == 2 { count } else { width }
		h := if i < 2 { ch } else if i == 2 { 2 } else { height }
		if plane.width != w || plane.height != h { return error('Invalid JPEG XL HF metadata channel shape') }
	}
	mut x_colors := []i32{len: cw * ch}
	mut b_colors := []i32{len: cw * ch}
	for i in 0 .. cw * ch {
		x := modular_storage_value(input[0].samples[i], storage)
		b := modular_storage_value(input[1].samples[i], storage)
		x_colors[i] = if x < -128 { -128 } else if x > 127 { 127 } else { x }
		b_colors[i] = if b < -128 { -128 } else if b > 127 { 127 } else { b }
	}
	mut transforms := []u8{len: width * height, init: u8(27)}
	mut quant := []i32{len: width * height}
	mut sharpness := []u8{len: width * height}
	mut index := 0
	for y in 0 .. height {
		for x in 0 .. width {
			position := y * width + x
			epf := modular_storage_value(input[3].samples[position], storage)
			if epf < 0 || epf >= 8 { return error('Invalid JPEG XL HF sharpness') }
			sharpness[position] = u8(epf)
			if transforms[position] != 27 { continue }
			if index >= count { return error('Incomplete JPEG XL HF transform records') }
			raw_transform := modular_storage_value(input[2].samples[index], storage)
			transform := hf_transform_from_id(int(raw_transform))!
			raw_quant := modular_storage_value(input[2].samples[count + index], storage)
			q := i32(1) + if raw_quant < 0 { i32(0) } else if raw_quant > 255 { i32(255) } else { raw_quant }
			dims := transform.covered_blocks()
			if (dims[0] > 1 || dims[1] > 1) && !is444 { return error('JPEG XL subsampled HF transform must cover one block') }
			x_boundary := if ((x / 32) + 1) * 32 < width { ((x / 32) + 1) * 32 } else { width }
			y_boundary := if ((y / 32) + 1) * 32 < height { ((y / 32) + 1) * 32 } else { height }
			if dims[0] > x_boundary - x || dims[1] > y_boundary - y {
				return error('JPEG XL HF transform crosses a group boundary')
			}
			index++
			for iy in 0 .. dims[1] {
				for ix in 0 .. dims[0] {
					p := (y + iy) * width + x + ix
					transforms[p] = u8(raw_transform) | if ix == 0 && iy == 0 { u8(128) } else { u8(0) }
					quant[p] = q
				}
			}
		}
	}
	return HfMetadata{ width: width, height: height,
		colors: HfGroupColorMap{ y_to_x: x_colors, y_to_b: b_colors },
		raw_quant: quant, transform_ids: transforms, sharpness: sharpness }
}
