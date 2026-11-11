// Copyright (c) 2022, the SerenityOS developers.
// Copyright (c) 2023, Sam Atkins <atkinssj@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// LibGfx/Font/WOFF/Loader.cpp: Header, table directory and sfnt reconstruction.
module gfxfont

import compress.zlib
import encoding.binary
import math.bits

struct WoffTableOutput {
mut:
	bytes    []u8
	written  int
	exceeded bool
}

fn copy_woff_table_chunk(chunk []u8, userdata voidptr) int {
	mut output := unsafe { &WoffTableOutput(userdata) }
	if chunk.len > output.bytes.len - output.written {
		output.exceeded = true
		return 0
	}
	copy(mut output.bytes[output.written..output.written + chunk.len], chunk)
	output.written += chunk.len
	return chunk.len
}

pub fn convert_woff_to_sfnt(buffer []u8) ![]u8 {
	if buffer.len < 44 { return error('Truncated WOFF header') }
	if binary.big_endian_u32(buffer) != 0x774f4646 { return error('Invalid WOFF signature') }
	flavor := binary.big_endian_u32_at(buffer, 4)
	length := binary.big_endian_u32_at(buffer, 8)
	num_tables := binary.big_endian_u16_at(buffer, 12)
	reserved := binary.big_endian_u16_at(buffer, 14)
	total_sfnt_size := binary.big_endian_u32_at(buffer, 16)
	meta_offset := binary.big_endian_u32_at(buffer, 24)
	meta_length := binary.big_endian_u32_at(buffer, 28)
	priv_offset := binary.big_endian_u32_at(buffer, 36)
	priv_length := binary.big_endian_u32_at(buffer, 40)
	mut expected_total_sfnt_size := u64(12) + u64(num_tables) * 16
	if u64(length) > u64(buffer.len) { return error('Invalid WOFF length') }
	if num_tables == 0 || num_tables > 65535 / 16 { return error('Invalid WOFF numTables') }
	if reserved != 0 { return error('Invalid WOFF reserved field') }
	if meta_length == 0 && meta_offset != 0 { return error('Invalid WOFF meta block offset') }
	if priv_length == 0 && priv_offset != 0 { return error('Invalid WOFF private block offset') }
	if 44 + u64(num_tables) * 20 > u64(length) { return error('Truncated WOFF table directory') }
	if u64(total_sfnt_size) < expected_total_sfnt_size {
		return error('Invalid WOFF total sfnt size')
	}
	if total_sfnt_size > 10 * 1024 * 1024 { return error('Uncompressed font is more than 10 MiB') }
	mut output := []u8{len: int(total_sfnt_size)}
	// Preserve the source pow_2_less_than_or_equal calculation, including its
	// x - 1 argument to count_leading_zeroes_safe.
	search_range := u16(1) << (16 - bits.leading_zeros_16(num_tables - 1))
	binary.big_endian_put_u32_at(mut output, flavor, 0)
	binary.big_endian_put_u16_at(mut output, num_tables, 4)
	binary.big_endian_put_u16_at(mut output, search_range * 16, 6)
	binary.big_endian_put_u16_at(mut output, u16(15 - bits.leading_zeros_16(search_range)), 8)
	binary.big_endian_put_u16_at(mut output, num_tables * 16 - search_range * 16, 10)
	mut font_buffer_offset := 12 + int(num_tables) * 16
	for i in 0 .. int(num_tables) {
		directory_offset := 44 + i * 20
		tag := binary.big_endian_u32_at(buffer, directory_offset)
		offset := binary.big_endian_u32_at(buffer, directory_offset + 4)
		comp_length := binary.big_endian_u32_at(buffer, directory_offset + 8)
		orig_length := binary.big_endian_u32_at(buffer, directory_offset + 12)
		checksum := binary.big_endian_u32_at(buffer, directory_offset + 16)
		expected_total_sfnt_size += (orig_length + u32(3)) & u32(0xfffffffc)
		if expected_total_sfnt_size > u64(total_sfnt_size) {
			return error('Invalid WOFF total sfnt size')
		}
		if u64(offset) + u64(comp_length) > u64(length) { return error('Truncated WOFF table') }
		if u64(font_buffer_offset) + u64(orig_length) > u64(output.len) {
			return error('Uncompressed WOFF table too big')
		}
		table := buffer[int(offset)..int(u64(offset) + comp_length)]
		if comp_length < orig_length {
			// Stream into the allocated table slot and abort as soon as a chunk
			// exceeds orig_length. The decoder keeps only a bounded overshoot.
			mut table_output := WoffTableOutput{
				bytes: unsafe { output[font_buffer_offset..font_buffer_offset + int(orig_length)] }
			}
			decompressed_size := zlib.decompress_with_callback(table, copy_woff_table_chunk,
				&table_output)!
			if table_output.exceeded || u64(decompressed_size) != u64(orig_length) {
				return error('Invalid decompressed WOFF table length')
			}
		} else {
			if comp_length != orig_length { return error('Invalid uncompressed WOFF table length') }
			copy(mut output[font_buffer_offset..font_buffer_offset + int(orig_length)], table)
		}
		table_directory_offset := 12 + i * 16
		binary.big_endian_put_u32_at(mut output, tag, table_directory_offset)
		binary.big_endian_put_u32_at(mut output, checksum, table_directory_offset + 4)
		binary.big_endian_put_u32_at(mut output, u32(font_buffer_offset),
			table_directory_offset + 8)
		binary.big_endian_put_u32_at(mut output, orig_length, table_directory_offset + 12)
		// Every reconstructed sfnt table starts on a four-byte boundary.
		font_buffer_offset += int((orig_length + u32(3)) & u32(0xfffffffc))
	}
	if u64(total_sfnt_size) != expected_total_sfnt_size {
		return error('Invalid WOFF total sfnt size')
	}
	return output
}
