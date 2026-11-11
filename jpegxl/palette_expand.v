// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

pub fn lookup_modular_palette(palette ModularChannel, channel int, bit_depth u32, index i32, storage ModularStorage) !i32 {
	palette.validate()!
	return lookup_validated_palette(palette, channel, bit_depth, index, storage)
}

// lookup_modular_palette for a palette whose shape the caller has validated.
fn lookup_validated_palette(palette ModularChannel, channel int, bit_depth u32, index i32, storage ModularStorage) !i32 {
	if channel < 0 || (palette.width > 0 && channel >= palette.height) {
		return error('Invalid JPEG XL palette channel')
	}
	if index >= 0 && i64(index) < palette.width {
		return modular_storage_value(palette.samples[channel * palette.width + int(index)], storage)
	}
	if channel >= 3 { return 0 }
	depth := math.min(bit_depth, u32(24))
	if index < 0 {
		delta := int(-(i64(index) + 1) % 143)
		sign := if delta & 1 == 0 { -1 } else { 1 }
		value := modular_delta_palette[(delta + 1) >> 1][channel] * sign
		return if depth > 8 { value * (i32(1) << (depth - 8)) } else { value }
	}
	cube := int(index) - palette.width
	scale := (u32(1) << depth) - 1
	if cube < 64 {
		value := u32((cube >> (channel * 2)) % 4)
		offset_shift := if depth > 3 { depth - 3 } else { u32(0) }
		offset := i32(u32(1) << offset_shift)
		return i32(value * scale / 4) + offset
	}
	entry := (cube - 64) % 125
	divisor := if channel == 0 {
		1
	} else if channel == 1 {
		5
	} else {
		25
	}
	return i32(u32((entry / divisor) % 5) * scale / 4)
}

// Reconstruct a complete image, without tiled borders or partial row checkpoints.
pub fn inverse_modular_palette(indices ModularChannel, palette ModularChannel, bit_depths []u32, num_deltas u32, predictor Predictor, weighted_header WeightedPredictorHeader, storage ModularStorage, partial bool) ![]ModularChannel {
	indices.validate()!
	palette.validate()!
	if bit_depths.len == 0 || bit_depths.len > 65536
		|| (palette.width > 0 && palette.height < bit_depths.len)
		|| u64(indices.samples.len) * u64(bit_depths.len) > 67108864 {
		return error('Invalid JPEG XL palette expansion dimensions')
	}
	clip := partial && predictor == .zero && num_deltas == 0 && bit_depths.len == 1 && palette.width > 0
	if clip && storage == .signed16 && palette.width > 32768 {
		return error('Invalid JPEG XL narrow partial palette range')
	}
	mut output := []ModularChannel{cap: bit_depths.len}
	for c, depth in bit_depths {
		mut result := ModularChannel.new(indices.width, indices.height, indices.shift)!
		if indices.samples.len == 0 {
			output << result
			continue
		}
		mut weighted := if predictor == .weighted {
			WeightedPredictorState.new(weighted_header, indices.width)!
		} else {
			WeightedPredictorState{}
		}
		mut current := []i32{len: indices.width}
		mut top := []i32{len: indices.width}
		mut toptop := []i32{len: indices.width}
		for y in 0 .. indices.height {
			for x in 0 .. indices.width {
				mut index := modular_storage_value(indices.samples[y * indices.width + x], storage)
				if clip { index = math.max(i32(0), math.min(index, i32(palette.width - 1))) }
				entry := lookup_validated_palette(palette, c, depth, index, storage)!
				data := prediction_data_in_rows(current, top, toptop, x, y)
				guess := if predictor == .weighted {
					weighted.predict_and_property(x, y & 1, data)!.value
				} else {
					predictor.predict_one(data, 0)
				}
				value := if index < i32(num_deltas) {
					make_modular_pixel(entry, 1, guess)
				} else {
					entry
				}
				if predictor == .weighted { weighted.update_errors(value, x, y & 1)! }
				current[x] = value
				result.samples[y * indices.width + x] = modular_storage_value(value, storage)
			}
			unsafe {
				old := toptop
				toptop = top
				top = current
				current = old
			}
		}
		output << result
	}
	return output
}
