// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

struct HuffmanNode {
mut:
	children [2]int = [-1, -1]!
	symbol   int    = -1
}

struct HuffmanEntry {
	node   int
	bits   int
	symbol int
}

pub struct HuffmanTable {
	nodes   []HuffmanNode
	primary []HuffmanEntry
}

// Canonical prefix codes use the same symbol ordering as the source's reversed
// two-level table. An eight-bit primary table points into a bounded binary tail.
fn build_huffman(lengths []u8) !HuffmanTable {
	if lengths.len == 0 || lengths.len > 32768 { return error('Invalid JPEG XL Huffman alphabet') }
	mut counts := [16]int{}
	mut nonzero := 0
	mut single := 0
	for symbol, length in lengths {
		if length > 15 { return error('Invalid JPEG XL Huffman length') }
		if length != 0 {
			counts[int(length)]++
			nonzero++
			single = symbol
		}
	}
	if nonzero == 0 { return error('Empty JPEG XL Huffman code') }
	if nonzero == 1 {
		return HuffmanTable{
			nodes:   [HuffmanNode{ symbol: single }]
			primary: []HuffmanEntry{len: 256, init: HuffmanEntry{ symbol: single }}
		}
	}
	mut space := 1
	mut next_codes := [16]int{}
	mut code := 0
	for length in 1 .. 16 {
		space = space * 2 - counts[length]
		if space < 0 { return error('Oversubscribed JPEG XL Huffman code') }
		code = (code + counts[length - 1]) << 1
		next_codes[length] = code
	}
	if space != 0 { return error('Incomplete JPEG XL Huffman code') }
	mut nodes := [HuffmanNode{}]
	for symbol, length in lengths {
		if length == 0 { continue }
		value := next_codes[int(length)]
		next_codes[int(length)]++
		mut node := 0
		for depth in 0 .. int(length) {
			bit := (value >> (int(length) - depth - 1)) & 1
			if nodes[node].children[bit] < 0 {
				next := nodes.len
				nodes << HuffmanNode{}
				nodes[node].children[bit] = next
			}
			node = nodes[node].children[bit]
		}
		nodes[node].symbol = symbol
	}
	mut primary := []HuffmanEntry{cap: 256}
	for prefix in 0 .. 256 {
		mut node := 0
		mut depth := 0
		for depth < 8 && nodes[node].symbol < 0 {
			node = nodes[node].children[(prefix >> depth) & 1]
			depth++
		}
		primary << HuffmanEntry{ node: node, bits: depth, symbol: nodes[node].symbol }
	}
	return HuffmanTable{ nodes: nodes, primary: primary }
}

fn (table HuffmanTable) read_internal(mut reader BitReader, checked bool) !u32 {
	if table.primary.len != 256 { return error('Uninitialized JPEG XL Huffman table') }
	entry := table.primary[int(reader.peek(8)!)]
	if checked { reader.read(entry.bits)! } else { reader.read_optimistic(entry.bits)! }
	mut node := entry.node
	mut symbol := entry.symbol
	for symbol < 0 {
		bit := if checked { reader.read(1)! } else { reader.read_optimistic(1)! }
		node = table.nodes[node].children[int(bit)]
		symbol = table.nodes[node].symbol
	}
	return u32(symbol)
}

// Like the source's hot symbol reader, this uses zero-padded lookahead. The
// caller must validate reader.check_end() at the entropy section boundary.
pub fn (table HuffmanTable) read(mut reader BitReader) !u32 {
	return table.read_internal(mut reader, false)
}

fn read_simple_huffman(alphabet_size int, mut reader BitReader) !HuffmanTable {
	count := int(reader.read(2)! + 1)
	mut symbols := []int{cap: count}
	for _ in 0 .. count {
		symbol := int(reader.read(ceil_log2(alphabet_size))!)
		if symbol >= alphabet_size {
			return error('Invalid JPEG XL simple Huffman symbols')
		}
		symbols << symbol
	}
	for i, symbol in symbols {
		if symbol in symbols[..i] { return error('Duplicate JPEG XL simple Huffman symbols') }
	}
	mut lengths := []u8{len: alphabet_size}
	match count {
		1 { lengths[symbols[0]] = 1 }
		2 {
			for symbol in symbols { lengths[symbol] = 1 }
		}
		3 {
			lengths[symbols[0]] = 1
			lengths[symbols[1]] = 2
			lengths[symbols[2]] = 2
		}
		else {
			if reader.read(1)! != 0 {
				for i, symbol in symbols { lengths[symbol] = u8(if i < 2 { i + 1 } else { 3 }) }
			} else {
				for symbol in symbols { lengths[symbol] = 2 }
			}
		}
	}
	return build_huffman(lengths)
}

fn read_huffman_lengths(meta_lengths []u8, alphabet_size int, mut reader BitReader) ![]u8 {
	table := build_huffman(meta_lengths)!
	mut lengths := []u8{len: alphabet_size}
	mut symbol := 0
	mut previous := u8(8)
	mut repeat := 0
	mut repeat_length := u8(0)
	mut space := 1 << 15
	for symbol < alphabet_size && space > 0 {
		length := u8(table.read_internal(mut reader, true)!)
		if length < 16 {
			repeat = 0
			lengths[symbol] = length
			symbol++
			if length != 0 {
				previous = length
				space -= 32768 >> length
				if space < 0 { return error('Oversubscribed JPEG XL Huffman lengths') }
			}
		} else {
			extra := int(length) - 14
			new_length := if length == 16 { previous } else { u8(0) }
			if repeat_length != new_length {
				repeat = 0
				repeat_length = new_length
			}
			old_repeat := repeat
			if repeat > 0 { repeat = (repeat - 2) << extra }
			repeat += int(reader.read(extra)!) + 3
			delta := repeat - old_repeat
			if delta < 0 || delta > alphabet_size - symbol {
				return error('Invalid JPEG XL Huffman repetition')
			}
			for i in 0 .. delta { lengths[symbol + i] = repeat_length }
			symbol += delta
			if repeat_length != 0 {
				space -= delta << (15 - repeat_length)
				if space < 0 { return error('Oversubscribed JPEG XL Huffman repetition') }
			}
		}
	}
	if space != 0 { return error('Incomplete JPEG XL Huffman lengths') }
	return lengths
}

pub fn (mut reader BitReader) read_huffman_table(alphabet_size int) !HuffmanTable {
	if alphabet_size < 1 || alphabet_size >= 32768 {
		return error('Invalid JPEG XL Huffman alphabet')
	}
	if alphabet_size == 1 { return build_huffman([u8(1)]) }
	skip := int(reader.read(2)!)
	if skip == 1 { return read_simple_huffman(alphabet_size, mut reader) }
	static_bits := [2, 2, 2, 3, 2, 2, 2, 4, 2, 2, 2, 3, 2, 2, 2, 4]
	static_values := [u8(0), 4, 3, 2, 0, 4, 3, 1, 0, 4, 3, 2, 0, 4, 3, 5]
	order := [1, 2, 3, 4, 0, 5, 17, 6, 16, 7, 8, 9, 10, 11, 12, 13, 14, 15]
	mut meta_lengths := []u8{len: 18}
	mut space := 32
	mut count := 0
	for i in skip .. 18 {
		if space <= 0 { break }
		index := int(reader.peek(4)!)
		reader.read(static_bits[index])!
		length := static_values[index]
		meta_lengths[order[i]] = length
		if length != 0 {
			space -= 32 >> length
			count++
		}
	}
	if count != 1 && space != 0 { return error('Invalid JPEG XL Huffman code-length tree') }
	lengths := read_huffman_lengths(meta_lengths, alphabet_size, mut reader)!
	return build_huffman(lengths)
}

pub fn (mut reader BitReader) read_varint16() !u32 {
	if reader.read(1)! == 0 { return 0 }
	bits := int(reader.read(4)!)
	if bits == 0 { return 1 }
	return (u32(1) << bits) + u32(reader.read(bits)!)
}

pub struct HuffmanCodes {
	tables         []HuffmanTable
	alphabet_sizes []int
}

pub fn (mut reader BitReader) read_huffman_codes(contexts int) !HuffmanCodes {
	if contexts < 1 || contexts > 65536 { return error('Invalid JPEG XL Huffman context count') }
	mut sizes := []int{cap: contexts}
	for _ in 0 .. contexts {
		size := int(reader.read_varint16()!) + 1
		sizes << size
	}
	for size in sizes {
		if size >= 32768 { return error('JPEG XL Huffman alphabet too large') }
	}
	mut tables := []HuffmanTable{cap: contexts}
	for size in sizes { tables << reader.read_huffman_table(size)! }
	return HuffmanCodes{ tables: tables, alphabet_sizes: sizes }
}

pub fn (codes HuffmanCodes) read(context int, mut reader BitReader) !u32 {
	if context < 0 || context >= codes.tables.len {
		return error('Invalid JPEG XL Huffman context')
	}
	return codes.tables[context].read(mut reader)
}

pub fn (codes HuffmanCodes) single_symbol(context int) ?u32 {
	if context < 0 || context >= codes.tables.len { return none }
	root := codes.tables[context].nodes[0]
	if root.symbol < 0 { return none }
	return u32(root.symbol)
}

pub fn (codes HuffmanCodes) max_symbol_for_cluster(cluster int) !u32 {
	if cluster < 0 || cluster >= codes.alphabet_sizes.len {
		return error('Invalid JPEG XL Huffman context')
	}
	return u32(codes.alphabet_sizes[cluster] - 1)
}
