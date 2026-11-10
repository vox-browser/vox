// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

// BitReader owns a view of its input. JPEG XL serializes least-significant bits first.
// A failed checked read leaves the cursor unchanged; optimistic reads require check_end().
pub struct BitReader {
	data []u8
pub mut:
	position int
}

pub fn new_bit_reader(data []u8) BitReader {
	return BitReader{ data: data }
}

pub fn (b &BitReader) available_bits() int {
	return math.max(0, b.data.len * 8 - b.position)
}

pub fn (b &BitReader) peek(n int) !u64 {
	if n < 0 || n > 56 || b.position < 0 {
		return error('Invalid JPEG XL bit count')
	}
	if n == 0 { return 0 }
	start := b.position / 8
	offset := b.position % 8
	if start + 8 <= b.data.len {
		// n <= 56 and offset <= 7, so eight bytes hold every requested bit. The
		// C compiler folds this little-endian composition into one load.
		p := unsafe { &u8(b.data.data) + start }
		word := unsafe {
			u64(p[0]) | (u64(p[1]) << 8) | (u64(p[2]) << 16) | (u64(p[3]) << 24) | (u64(p[4]) << 32) | (u64(p[5]) << 40) | (u64(p[6]) << 48) | (u64(p[7]) << 56)
		}
		return (word >> offset) & ((u64(1) << n) - 1)
	}
	count := math.min((n + offset + 7) / 8, math.max(0, b.data.len - start))
	mut value := u64(0)
	for i in 0 .. count {
		value |= u64(b.data[start + i]) << (i * 8)
	}
	return (value >> offset) & ((u64(1) << n) - 1)
}

pub fn (mut b BitReader) read(n int) !u64 {
	value := b.peek(n)!
	if n > b.available_bits() { return error('Truncated JPEG XL bitstream') }
	b.position += n
	return value
}

pub fn (mut b BitReader) read_optimistic(n int) !u64 {
	value := b.peek(n)!
	b.position += n
	return value
}

pub fn (b &BitReader) check_end() ! {
	if b.position < 0 || b.position > b.data.len * 8 {
		return error('Truncated JPEG XL bitstream')
	}
}

pub fn (mut b BitReader) skip(n int) ! {
	if n < 0 { return error('Invalid JPEG XL bit count') }
	if n > b.available_bits() {
		b.position = b.data.len * 8
		return error('Truncated JPEG XL bitstream')
	}
	b.position += n
}

pub fn (mut b BitReader) align_to_byte() ! {
	padding := (8 - b.position % 8) % 8
	if b.read(padding)! != 0 { return error('Nonzero JPEG XL padding') }
}

// The returned view cannot read into the following section.
pub fn (mut b BitReader) split_bytes(n int) !BitReader {
	b.align_to_byte()!
	if n < 0 { return error('Invalid JPEG XL section size') }
	if n > b.available_bits() / 8 {
		b.position = b.data.len * 8
		return error('Truncated JPEG XL section')
	}
	start := b.position / 8
	b.position += n * 8
	return new_bit_reader(b.data[start..start + n])
}
