// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

const lz77_window_size = 1 << 20
const lz77_window_mask = u32(lz77_window_size - 1)

struct Lz77Distance {
	x int
	y int
}

struct Lz77State {
	min_symbol          u32
	min_length          u32
	distance_multiplier u32
mut:
	window        []u32
	to_copy       u32
	copy_position u32
	decoded       u32
}

fn (mut state Lz77State) apply_copy(symbol u32, count u32) {
	mut distance_minus_one := symbol
	if state.distance_multiplier != 0 {
		if symbol >= 120 {
			distance_minus_one = symbol - 120
		} else {
			offset := lz77_special_distances[int(symbol)]
			product := u64(state.distance_multiplier) * u64(offset.y)
			candidate := i64(product) + i64(offset.x) - 1
			distance_minus_one = if product <= u64(0xffffffff) && candidate >= 0 && candidate <= i64(0xffffffff) {
				u32(candidate)
			} else {
				u32(0)
			}
		}
	}
	distance := math.min(math.min(lz77_window_mask, distance_minus_one) + 1, state.decoded)
	state.copy_position = state.decoded - distance
	state.to_copy = count
}

fn (mut state Lz77State) push(symbol u32) {
	offset := int(state.decoded & lz77_window_mask)
	if offset < state.window.len { state.window[offset] = symbol } else { state.window << symbol }
	state.decoded++
}

fn (mut state Lz77State) pull() ?u32 {
	if state.to_copy == 0 { return none }
	symbol := state.window[int(state.copy_position & lz77_window_mask)]
	state.copy_position++
	state.to_copy--
	return symbol
}

const lz77_special_distances = [
	Lz77Distance{ x: 0, y: 1 },
	Lz77Distance{ x: 1, y: 0 },
	Lz77Distance{ x: 1, y: 1 },
	Lz77Distance{ x: -1, y: 1 },
	Lz77Distance{ x: 0, y: 2 },
	Lz77Distance{ x: 2, y: 0 },
	Lz77Distance{ x: 1, y: 2 },
	Lz77Distance{ x: -1, y: 2 },
	Lz77Distance{ x: 2, y: 1 },
	Lz77Distance{ x: -2, y: 1 },
	Lz77Distance{ x: 2, y: 2 },
	Lz77Distance{ x: -2, y: 2 },
	Lz77Distance{ x: 0, y: 3 },
	Lz77Distance{ x: 3, y: 0 },
	Lz77Distance{ x: 1, y: 3 },
	Lz77Distance{ x: -1, y: 3 },
	Lz77Distance{ x: 3, y: 1 },
	Lz77Distance{ x: -3, y: 1 },
	Lz77Distance{ x: 2, y: 3 },
	Lz77Distance{ x: -2, y: 3 },
	Lz77Distance{ x: 3, y: 2 },
	Lz77Distance{ x: -3, y: 2 },
	Lz77Distance{ x: 0, y: 4 },
	Lz77Distance{ x: 4, y: 0 },
	Lz77Distance{ x: 1, y: 4 },
	Lz77Distance{ x: -1, y: 4 },
	Lz77Distance{ x: 4, y: 1 },
	Lz77Distance{ x: -4, y: 1 },
	Lz77Distance{ x: 3, y: 3 },
	Lz77Distance{ x: -3, y: 3 },
	Lz77Distance{ x: 2, y: 4 },
	Lz77Distance{ x: -2, y: 4 },
	Lz77Distance{ x: 4, y: 2 },
	Lz77Distance{ x: -4, y: 2 },
	Lz77Distance{ x: 0, y: 5 },
	Lz77Distance{ x: 3, y: 4 },
	Lz77Distance{ x: -3, y: 4 },
	Lz77Distance{ x: 4, y: 3 },
	Lz77Distance{ x: -4, y: 3 },
	Lz77Distance{ x: 5, y: 0 },
	Lz77Distance{ x: 1, y: 5 },
	Lz77Distance{ x: -1, y: 5 },
	Lz77Distance{ x: 5, y: 1 },
	Lz77Distance{ x: -5, y: 1 },
	Lz77Distance{ x: 2, y: 5 },
	Lz77Distance{ x: -2, y: 5 },
	Lz77Distance{ x: 5, y: 2 },
	Lz77Distance{ x: -5, y: 2 },
	Lz77Distance{ x: 4, y: 4 },
	Lz77Distance{ x: -4, y: 4 },
	Lz77Distance{ x: 3, y: 5 },
	Lz77Distance{ x: -3, y: 5 },
	Lz77Distance{ x: 5, y: 3 },
	Lz77Distance{ x: -5, y: 3 },
	Lz77Distance{ x: 0, y: 6 },
	Lz77Distance{ x: 6, y: 0 },
	Lz77Distance{ x: 1, y: 6 },
	Lz77Distance{ x: -1, y: 6 },
	Lz77Distance{ x: 6, y: 1 },
	Lz77Distance{ x: -6, y: 1 },
	Lz77Distance{ x: 2, y: 6 },
	Lz77Distance{ x: -2, y: 6 },
	Lz77Distance{ x: 6, y: 2 },
	Lz77Distance{ x: -6, y: 2 },
	Lz77Distance{ x: 4, y: 5 },
	Lz77Distance{ x: -4, y: 5 },
	Lz77Distance{ x: 5, y: 4 },
	Lz77Distance{ x: -5, y: 4 },
	Lz77Distance{ x: 3, y: 6 },
	Lz77Distance{ x: -3, y: 6 },
	Lz77Distance{ x: 6, y: 3 },
	Lz77Distance{ x: -6, y: 3 },
	Lz77Distance{ x: 0, y: 7 },
	Lz77Distance{ x: 7, y: 0 },
	Lz77Distance{ x: 1, y: 7 },
	Lz77Distance{ x: -1, y: 7 },
	Lz77Distance{ x: 5, y: 5 },
	Lz77Distance{ x: -5, y: 5 },
	Lz77Distance{ x: 7, y: 1 },
	Lz77Distance{ x: -7, y: 1 },
	Lz77Distance{ x: 4, y: 6 },
	Lz77Distance{ x: -4, y: 6 },
	Lz77Distance{ x: 6, y: 4 },
	Lz77Distance{ x: -6, y: 4 },
	Lz77Distance{ x: 2, y: 7 },
	Lz77Distance{ x: -2, y: 7 },
	Lz77Distance{ x: 7, y: 2 },
	Lz77Distance{ x: -7, y: 2 },
	Lz77Distance{ x: 3, y: 7 },
	Lz77Distance{ x: -3, y: 7 },
	Lz77Distance{ x: 7, y: 3 },
	Lz77Distance{ x: -7, y: 3 },
	Lz77Distance{ x: 5, y: 6 },
	Lz77Distance{ x: -5, y: 6 },
	Lz77Distance{ x: 6, y: 5 },
	Lz77Distance{ x: -6, y: 5 },
	Lz77Distance{ x: 8, y: 0 },
	Lz77Distance{ x: 4, y: 7 },
	Lz77Distance{ x: -4, y: 7 },
	Lz77Distance{ x: 7, y: 4 },
	Lz77Distance{ x: -7, y: 4 },
	Lz77Distance{ x: 8, y: 1 },
	Lz77Distance{ x: 8, y: 2 },
	Lz77Distance{ x: 6, y: 6 },
	Lz77Distance{ x: -6, y: 6 },
	Lz77Distance{ x: 8, y: 3 },
	Lz77Distance{ x: 5, y: 7 },
	Lz77Distance{ x: -5, y: 7 },
	Lz77Distance{ x: 7, y: 5 },
	Lz77Distance{ x: -7, y: 5 },
	Lz77Distance{ x: 8, y: 4 },
	Lz77Distance{ x: 6, y: 7 },
	Lz77Distance{ x: -6, y: 7 },
	Lz77Distance{ x: 7, y: 6 },
	Lz77Distance{ x: -7, y: 6 },
	Lz77Distance{ x: 8, y: 5 },
	Lz77Distance{ x: 7, y: 7 },
	Lz77Distance{ x: -7, y: 7 },
	Lz77Distance{ x: 8, y: 6 },
	Lz77Distance{ x: 8, y: 7 },
]
