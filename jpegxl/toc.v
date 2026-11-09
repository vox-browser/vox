// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct FrameToc {
pub:
	permuted    bool
	permutation Permutation
	entries     []u32
}

fn (mut reader BitReader) read_toc_size() !u32 {
	return reader.read_u32([U32Code{ bits: 10 }, U32Code{ bits: 14, offset: 1024 },
		U32Code{ bits: 22, offset: 17408 }, U32Code{ bits: 30, offset: 4211712 }]!)
}

pub fn (mut reader BitReader) read_toc(entries int) !FrameToc {
	if entries < 0 || entries > max_permutation_entries { return error('Invalid JPEG XL TOC size') }
	permuted := reader.read(1)! != 0
	permutation := reader.read_permutation(entries, permuted)!
	mut sizes := []u32{cap: entries}
	for _ in 0 .. entries { sizes << reader.read_toc_size()! }
	return FrameToc{ permuted: permuted, permutation: permutation, entries: sizes }
}

pub struct IncrementalTocReader {
	count    int
	permuted bool
mut:
	have_permutation bool
	permutation      Permutation
	entries          []u32
}

pub fn IncrementalTocReader.new(entries int, mut reader BitReader) !IncrementalTocReader {
	if entries < 0 || entries > max_permutation_entries { return error('Invalid JPEG XL TOC size') }
	return IncrementalTocReader{ count: entries, permuted: reader.read(1)! != 0 }
}

pub fn (toc IncrementalTocReader) num_read_entries() int { return toc.entries.len }

pub fn (toc IncrementalTocReader) remaining_entries() int { return toc.count - toc.entries.len }

pub fn (toc IncrementalTocReader) is_complete() bool {
	return toc.have_permutation && toc.remaining_entries() == 0
}

// A caller retries a failed step with its BitReader cursor restored. Completed
// entries remain committed; a failed size read never appends an entry.
pub fn (mut toc IncrementalTocReader) read_step(mut reader BitReader) ! {
	if toc.is_complete() { return error('JPEG XL TOC is already complete') }
	if !toc.have_permutation {
		permutation := reader.read_permutation(toc.count, toc.permuted)!
		toc.permutation = permutation
		toc.have_permutation = true
		reader.check_end()!
		return
	}
	entry := reader.read_toc_size()!
	toc.entries << entry
	reader.check_end()!
}

pub fn (toc IncrementalTocReader) finalize() !FrameToc {
	if !toc.is_complete() { return error('Incomplete JPEG XL TOC') }
	return FrameToc{ permuted: toc.permuted, permutation: toc.permutation, entries: toc.entries }
}

pub fn (mut reader BitReader) read_sections(toc FrameToc) ![]BitReader {
	if toc.permuted && toc.permutation.values.len != toc.entries.len {
		return error('JPEG XL TOC permutation size mismatch')
	}
	mut physical := []BitReader{cap: toc.entries.len}
	for size in toc.entries { physical << reader.split_bytes(int(size))! }
	if !toc.permuted { return physical }
	mut ordered := []BitReader{cap: physical.len}
	mut seen := []bool{len: physical.len}
	for index in toc.permutation.values {
		if u64(index) >= u64(physical.len) || seen[int(index)] {
			return error('Invalid JPEG XL TOC permutation')
		}
		seen[int(index)] = true
		ordered << physical[int(index)]
	}
	return ordered
}
