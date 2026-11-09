// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

const coefficient_order_count = 13
const nonzero_context_buckets = 37
const zero_density_context_count = 458
const zero_density_context_limit = 474
const coefficient_frequency_context = [0xbad, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14,
	15, 15, 16, 16, 17, 17, 18, 18, 19, 19, 20, 20, 21, 21, 22, 22, 23, 23, 23, 23, 24, 24, 24,
	24, 25, 25, 25, 25, 26, 26, 26, 26, 27, 27, 27, 27, 28, 28, 28, 28, 29, 29, 29, 29, 30, 30,
	30, 30]!
const coefficient_nonzero_context = [0xbad, 0, 31, 62, 62, 93, 93, 93, 93, 123, 123, 123, 123,
	152, 152, 152, 152, 152, 152, 152, 152, 180, 180, 180, 180, 180, 180, 180, 180, 180, 180, 180,
	180, 206, 206, 206, 206, 206, 206, 206, 206, 206, 206, 206, 206, 206, 206, 206, 206, 206, 206,
	206, 206, 206, 206, 206, 206, 206, 206, 206, 206, 206, 206, 206]!

pub struct BlockContextMap {
pub:
	lf_thresholds   [3][]i32
	qf_thresholds   []u32
	context_map     []u8
	num_lf_contexts int
	num_contexts    int
}

pub fn (mut reader BitReader) read_block_context_map() !BlockContextMap {
	if reader.read(1)! == 1 {
		return BlockContextMap{
			context_map:     [u8(0), 1, 2, 2, 3, 3, 4, 5, 6, 6, 6, 6, 6, 7, 8, 9, 9, 10, 11, 12,
				13, 14, 14, 14, 14, 14, 7, 8, 9, 9, 10, 11, 12, 13, 14, 14, 14, 14, 14]
			num_lf_contexts: 1
			num_contexts:    15
		}
	}
	mut lf_thresholds := [3][]i32{}
	mut num_lf_contexts := 1
	for c in 0 .. 3 {
		count := int(reader.read(4)!)
		mut thresholds := []i32{len: count}
		for i in 0 .. count {
			selector := reader.read(2)!
			unsigned := match selector {
				0 { reader.read(4)! }
				1 { reader.read(8)! + 16 }
				2 { reader.read(16)! + 272 }
				else { reader.read(32)! + 65808 }
			}
			// The source deliberately truncates the 32-bit selector's offset sum.
			thresholds[i] = unpack_signed(u32(unsigned))
		}
		lf_thresholds[c] = thresholds
		num_lf_contexts *= count + 1
	}
	count := int(reader.read(4)!)
	mut qf_thresholds := []u32{len: count}
	for i in 0 .. count {
		qf_thresholds[i] = reader.read_u32([U32Code{ bits: 2 }, U32Code{ bits: 3, offset: 4 },
			U32Code{ bits: 5, offset: 12 }, U32Code{ bits: 8, offset: 44 }]!)! + 1
	}
	if num_lf_contexts * (count + 1) > 64 {
		return error('JPEG XL block context map is too large')
	}
	contexts := reader.read_context_map(3 * coefficient_order_count * num_lf_contexts * (count + 1))!
	mut num_contexts := 1
	for context in contexts {
		if int(context) + 1 > num_contexts { num_contexts = int(context) + 1 }
	}
	if num_contexts > 16 { return error('Too many JPEG XL block contexts') }
	return BlockContextMap{
		lf_thresholds:   lf_thresholds
		qf_thresholds:   qf_thresholds
		context_map:     contexts
		num_lf_contexts: num_lf_contexts
		num_contexts:    num_contexts
	}
}

pub fn (map_ BlockContextMap) num_ac_contexts() int {
	return map_.num_contexts * (nonzero_context_buckets + zero_density_context_count)
}

pub fn (map_ BlockContextMap) block_context(lf_idx int, qf u32, shape_id int, channel int) !int {
	if map_.num_lf_contexts < 1 || map_.num_lf_contexts > 64 || map_.num_contexts < 1
		|| map_.num_contexts > 16 || map_.qf_thresholds.len > 15 || lf_idx < 0
		|| lf_idx >= map_.num_lf_contexts || shape_id < 0 || shape_id >= coefficient_order_count
		|| channel < 0 || channel > 2 {
		return error('Invalid JPEG XL block context dimensions')
	}
	if map_.context_map.len != 3 * coefficient_order_count * map_.num_lf_contexts * (map_.qf_thresholds.len + 1) {
		return error('Invalid JPEG XL block context storage')
	}
	mut qf_idx := 0
	for threshold in map_.qf_thresholds {
		if qf > threshold { qf_idx++ }
	}
	component := if channel < 2 { channel ^ 1 } else { 2 }
	index := ((component * coefficient_order_count + shape_id) * (map_.qf_thresholds.len + 1) + qf_idx) * map_.num_lf_contexts + lf_idx
	context := int(map_.context_map[index])
	if context >= map_.num_contexts { return error('Invalid JPEG XL block context cluster') }
	return context
}

fn (map_ BlockContextMap) check_block_context(context int) ! {
	if map_.num_contexts < 1 || map_.num_contexts > 16 || context < 0 || context >= map_.num_contexts {
		return error('Invalid JPEG XL block context')
	}
}

pub fn (map_ BlockContextMap) nonzero_context(nonzeros u32, block_context int) !int {
	map_.check_block_context(block_context)!
	bucket := if nonzeros < 8 {
		int(nonzeros)
	} else if nonzeros < 64 {
		4 + int(nonzeros / 2)
	} else {
		36
	}
	return bucket * map_.num_contexts + block_context
}

pub fn (map_ BlockContextMap) zero_density_context_offset(block_context int) !int {
	map_.check_block_context(block_context)!
	return map_.num_contexts * nonzero_context_buckets + zero_density_context_count * block_context
}

pub fn zero_density_context(nonzeros_left u32, k u32, log_num_blocks int, previous bool) !int {
	// VarDCT orders cover at most 32 by 32 blocks.
	if log_num_blocks < 0 || log_num_blocks > 10 {
		return error('Invalid JPEG XL coefficient block scale')
	}
	blocks := u32(1) << log_num_blocks
	nz := nonzeros_left / blocks + if nonzeros_left % blocks == 0 { u32(0) } else { u32(1) }
	frequency := k >> log_num_blocks
	if nz < 1 || nz > 63 || frequency < 1 || frequency > 63 {
		return error('Invalid JPEG XL zero density coordinates')
	}
	return (coefficient_nonzero_context[int(nz)] + coefficient_frequency_context[int(frequency)]) * 2 + if previous {
		1
	} else {
		0
	}
}
