// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct AnsCodes {
	histograms []AnsHistogram
}

pub fn (mut reader BitReader) read_ans_codes(contexts int, log_alphabet_size int) !AnsCodes {
	if contexts < 1 || contexts > 65536 || log_alphabet_size < 5 || log_alphabet_size > 8 {
		return error('Invalid JPEG XL ANS table dimensions')
	}
	mut histograms := []AnsHistogram{cap: contexts}
	for _ in 0 .. contexts { histograms << reader.read_ans_histogram(log_alphabet_size)! }
	return AnsCodes{ histograms: histograms }
}

pub fn (codes AnsCodes) single_symbol(context int) ?u32 {
	if context < 0 || context >= codes.histograms.len { return none }
	return codes.histograms[context].single_symbol
}

pub fn (codes AnsCodes) max_symbol_for_cluster(cluster int) !u32 {
	if cluster < 0 || cluster >= codes.histograms.len {
		return error('Invalid JPEG XL ANS context')
	}
	return u32(codes.histograms[cluster].alphabet_size - 1)
}

pub struct AnsReader {
pub mut:
	state u32 = 0x130000
}

pub fn (mut reader BitReader) read_ans_state() !AnsReader {
	return AnsReader{ state: u32(reader.read(32)!) }
}

pub fn (mut ans AnsReader) read(codes AnsCodes, context int, mut reader BitReader) !u32 {
	if context < 0 || context >= codes.histograms.len {
		return error('Invalid JPEG XL ANS context')
	}
	histogram := codes.histograms[context]
	index := ans.state & 0xfff
	bucket_index := int(index >> histogram.log_bucket_size)
	position := index & histogram.bucket_mask
	bucket := histogram.buckets[bucket_index]
	alias := position >= u32(bucket.alias_cutoff)
	distance := u32(bucket.distance) ^ if alias { u32(bucket.alias_distance_xor) } else { u32(0) }
	symbol := if alias { u32(bucket.alias_symbol) } else { u32(bucket_index) }
	offset := position + if alias { u32(bucket.alias_offset) } else { u32(0) }
	next := (ans.state >> 12) * distance + offset
	ans.state = if next < u32(1) << 16 {
		(next << 16) | u32(reader.read_bits_optimistic(16))
	} else {
		next
	}
	return symbol
}

pub fn (ans AnsReader) check_final_state() ! {
	if ans.state != 0x130000 { return error('JPEG XL ANS checksum mismatch') }
}
