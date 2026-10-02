// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
module webassembly

const binary_max_byte_vector_size = u32(500 * 1024 * 1024)

// Parser.cpp::parse_vector<u8> and Constants.h's byte-vector allocation limit.
// The V decoder owns its resulting bytes instead of exposing its input slice.
fn (mut decoder Decoder) byte_vector() ![]u8 {
	count := decoder.u32_leb()!
	if count > binary_max_byte_vector_size { return error('CompileError: byte vector exceeds source allocation limit') }
	if u64(count) > u64(decoder.bytes.len - decoder.offset) { return error('CompileError: unexpected end of byte vector') }
	bytes := decoder.bytes[decoder.offset..decoder.offset + int(count)].clone()
	decoder.offset += int(count)
	return bytes
}
