// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

// Shape IDs match the source transform-type LUT, including the Hornuss order.
const coefficient_blocks_x = [1, 1, 2, 4, 2, 4, 4, 8, 8, 16, 16, 32, 32]!
const coefficient_blocks_y = [1, 1, 2, 4, 1, 1, 2, 8, 4, 16, 8, 32, 16]!

pub fn natural_coefficient_order(shape_id int) ![]u32 {
	if shape_id < 0 || shape_id >= coefficient_order_count {
		return error('Invalid JPEG XL coefficient order shape')
	}
	cx := coefficient_blocks_x[shape_id]
	cy := coefficient_blocks_y[shape_id]
	xsize := cx * 8
	ratio := cx / cy
	mask := ratio - 1
	shift := ceil_log2(ratio)
	mut order := []u32{len: cx * cy * 64}
	mut current := cx * cy
	for i in 0 .. xsize {
		for j in 0 .. i + 1 {
			mut x := j
			mut y := i - j
			if i % 2 != 0 { x, y = y, x }
			if y & mask != 0 { continue }
			y >>= shift
			index := if x < cx && y < cy {
				y * cx + x
			} else {
				value := current
				current++
				value
			}
			order[index] = u32(y * xsize + x)
		}
	}
	for ir in 1 .. xsize {
		i := xsize - ir - 1
		for j in 0 .. i + 1 {
			mut x := xsize - 1 - (i - j)
			mut y := xsize - 1 - j
			if i % 2 != 0 { x, y = y, x }
			if y & mask != 0 { continue }
			y >>= shift
			order[current] = u32(y * xsize + x)
			current++
		}
	}
	return order
}

pub fn (mut reader BitReader) read_coefficient_orders(used_orders u32) ![]Permutation {
	mut orders := []Permutation{cap: coefficient_order_count * 3}
	for shape in 0 .. coefficient_order_count {
		natural := natural_coefficient_order(shape)!
		// Each component owns its order; composing one cannot mutate another.
		for _ in 0 .. 3 { orders << Permutation{ values: natural.clone() } }
	}
	if used_orders == 0 { return orders }
	histograms := reader.read_histograms(8, true)!
	mut symbols := SymbolReader.new(histograms, mut reader, none)!
	for shape in 0 .. coefficient_order_count {
		if used_orders & (u32(1) << shape) == 0 { continue }
		blocks := coefficient_blocks_x[shape] * coefficient_blocks_y[shape]
		for c in 0 .. 3 {
			permutation := decode_permutation(blocks * 64, blocks, histograms, mut reader, mut symbols)!
			orders[3 * shape + c].compose(permutation)!
		}
	}
	symbols.check_final_state(histograms, reader)!
	return orders
}
