// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

const max_permutation_entries = 1 << 24

pub struct Permutation {
pub mut:
	values []u32
}

fn permutation_context(value u32) int { return math.min(ceil_log2(int(value) + 1), 7) }

// Decode ranks in a shrinking sequence using an implicit order-statistics tree.
// Missing Lehmer digits are zero; the remaining input order is retained.
pub fn decode_lehmer_code(code []u32, base []u32) ![]u32 {
	if base.len == 0 || base.len > max_permutation_entries || code.len > base.len {
		return error('Invalid JPEG XL Lehmer dimensions')
	}
	if code.len == 0 { return base.clone() }
	mut padded := 1
	for padded < base.len { padded <<= 1 }
	mut tree := []u32{len: padded}
	for i in 0 .. padded {
		value := u32(i + 1)
		tree[i] = value & (~value + 1)
	}
	mut result := []u32{len: base.len}
	for i in 0 .. base.len {
		digit := if i < code.len { code[i] } else { u32(0) }
		if u64(digit) >= u64(base.len - i) { return error('Invalid JPEG XL Lehmer rank') }
		mut rank := digit + 1
		mut step := padded
		mut next := 0
		for step != 0 {
			candidate := next + step
			if candidate < 1 || candidate > padded { return error('Invalid JPEG XL Lehmer tree') }
			step >>= 1
			if tree[candidate - 1] < rank {
				next = candidate
				rank -= tree[candidate - 1]
			}
		}
		if next >= base.len { return error('Invalid JPEG XL Lehmer element') }
		result[i] = base[next]
		next++
		for next <= padded {
			tree[next - 1]--
			next += next & -next
		}
	}
	return result
}

pub fn permutation_from_lehmer(size int, skip int, code []u32) !Permutation {
	if size < 0 || size > max_permutation_entries || skip < 0 || skip >= size || code.len > size - skip {
		return error('Invalid JPEG XL permutation dimensions')
	}
	mut base := []u32{len: size - skip}
	for i in 0 .. base.len { base[i] = u32(i + skip) }
	tail := decode_lehmer_code(code, base)!
	mut values := []u32{len: size}
	for i in 0 .. skip { values[i] = u32(i) }
	for i, value in tail { values[i + skip] = value }
	return Permutation{ values: values }
}

pub fn decode_permutation(size int, skip int, histograms Histograms, mut reader BitReader, mut symbols SymbolReader) !Permutation {
	if size < 0 || size > max_permutation_entries || skip < 0 || skip > size {
		return error('Invalid JPEG XL permutation dimensions')
	}
	end := symbols.read_unsigned(&histograms, permutation_context(u32(size)), mut reader)!
	if u64(end) > u64(size - skip) { return error('Invalid JPEG XL permutation end') }
	mut code := []u32{cap: int(end)}
	mut previous := u32(0)
	for i in 0 .. int(end) {
		value := symbols.read_unsigned(&histograms, permutation_context(previous), mut reader)!
		reader.check_end()!
		if u64(value) >= u64(size - skip - i) {
			return error('Invalid JPEG XL entropy-coded Lehmer rank')
		}
		code << value
		previous = value
	}
	return permutation_from_lehmer(size, skip, code)
}

pub fn (mut reader BitReader) read_permutation(size int, permuted bool) !Permutation {
	if size < 0 || size > max_permutation_entries {
		return error('Invalid JPEG XL permutation size')
	}
	if !permuted {
		reader.align_to_byte()!
		return Permutation{}
	}
	histograms := reader.read_histograms(8, true)!
	mut symbols := SymbolReader.new(histograms, mut reader, none)!
	mut failure := ''
	permutation := decode_permutation(size, 0, histograms, mut reader, mut symbols) or {
		failure = err.msg()
		Permutation{}
	}
	// The source aligns after permutation decoding, including a decoded error.
	// It does not finalize the isolated symbol reader/check the ANS checksum here.
	reader.align_to_byte()!
	if failure != '' { return error(failure) }
	return permutation
}

pub fn (mut permutation Permutation) compose(other Permutation) ! {
	if permutation.values.len != other.values.len {
		return error('JPEG XL permutation composition size mismatch')
	}
	mut values := []u32{len: permutation.values.len}
	for i, index in other.values {
		if u64(index) >= u64(permutation.values.len) {
			return error('Invalid JPEG XL composition index')
		}
		values[i] = permutation.values[int(index)]
	}
	permutation.values = values
}
