// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

fn verify_context_map(map_ []u8) ! {
	mut seen := [256]bool{}
	mut maximum := 0
	mut distinct := 0
	for cluster in map_ {
		if !seen[int(cluster)] {
			seen[int(cluster)] = true
			distinct++
		}
		if int(cluster) + 1 > maximum { maximum = int(cluster) + 1 }
	}
	if distinct != maximum { return error('JPEG XL context map has a histogram hole') }
}

fn inverse_move_to_front(mut map_ []u8) {
	mut symbols := [256]u8{}
	for i in 0 .. 256 { symbols[i] = u8(i) }
	for i, index in map_ {
		value := symbols[int(index)]
		map_[i] = value
		for j := int(index); j > 0; j-- { symbols[j] = symbols[j - 1] }
		symbols[0] = value
	}
}

pub fn (mut reader BitReader) read_context_map(contexts int) ![]u8 {
	return reader.read_context_map_depth(contexts, 0)
}

fn (mut reader BitReader) read_context_map_depth(contexts int, depth int) ![]u8 {
	if contexts < 1 || contexts > 65537 || depth > 16 {
		return error('Invalid JPEG XL context map dimensions')
	}
	mut map_ := []u8{len: contexts}
	if reader.read(1)! != 0 {
		bits := int(reader.read(2)!)
		if bits != 0 {
			for i in 0 .. contexts { map_[i] = u8(reader.read(bits)!) }
		}
	} else {
		mtf := reader.read(1)! != 0
		hist := reader.read_histograms_depth(1, contexts > 2, depth + 1)!
		mut symbols := SymbolReader.new(hist, mut reader, none)!
		for i in 0 .. contexts {
			value := symbols.read_unsigned(&hist, 0, mut reader)!
			if value > 255 { return error('Invalid JPEG XL context map value') }
			map_[i] = u8(value)
		}
		symbols.check_final_state(hist, reader)!
		if mtf { inverse_move_to_front(mut map_) }
	}
	verify_context_map(map_)!
	return map_
}
