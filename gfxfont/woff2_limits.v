// Copyright (c) 2024, Andreas Kling <andreas@ladybird.org>
// SPDX-License-Identifier: BSD-2-Clause
// LibGfx/Font/WOFF2/Loader.cpp: reject oversized table data before decoding.
module gfxfont

const woff2_max_output_size = u64(30 * 1024 * 1024)

struct Woff2DirectoryReader {
	bytes []u8
mut:
	position int
}

fn (mut reader Woff2DirectoryReader) read_byte() !u8 {
	if reader.position >= reader.bytes.len { return error('Truncated WOFF2 table directory') }
	value := reader.bytes[reader.position]
	reader.position++
	return value
}

fn (mut reader Woff2DirectoryReader) read_uint_base128() !u32 {
	mut accumulator := u32(0)
	for i in 0 .. 5 {
		byte := reader.read_byte()!
		if i == 0 && byte == 0x80 { return error('UIntBase128 with leading zeros') }
		if accumulator & u32(0xfe000000) != 0 { return error('UIntBase128 overflow') }
		accumulator = (accumulator << 7) | u32(byte & 0x7f)
		if byte & 0x80 == 0 { return accumulator }
	}
	return error('UIntBase128 longer than 5 bytes')
}

// The native decoder allocates the complete Brotli table-data buffer before
// writing sfnt output. Bound that first allocation as well as the output writer.
fn woff2_decompressed_table_data_size(bytes []u8) !u64 {
	if bytes.len < 48 { return error('Truncated WOFF2 header') }
	num_tables := (u16(bytes[12]) << 8) | u16(bytes[13])
	mut reader := Woff2DirectoryReader{ bytes: bytes, position: 48 }
	mut size := u64(0)
	for _ in 0 .. int(num_tables) {
		flags := reader.read_byte()!
		tag_index := flags & 0x3f
		transform_version := flags >> 6
		mut is_glyf_or_loca := tag_index in [u8(10), 11]
		if tag_index == 0x3f {
			if bytes.len - reader.position < 4 { return error('Truncated WOFF2 table tag') }
			tag := bytes[reader.position..reader.position + 4].bytestr()
			reader.position += 4
			is_glyf_or_loca = tag in ['glyf', 'loca']
		}
		is_transformed := if is_glyf_or_loca { transform_version == 0 } else { transform_version != 0 }
		mut length := reader.read_uint_base128()!
		if is_transformed { length = reader.read_uint_base128()! }
		size += u64(length)
	}
	return size
}
