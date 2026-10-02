// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
module webassembly

pub struct BinaryTagType {
pub:
	type_index u32
	flags u8
}

pub struct BinaryTagImport {
pub:
	module string
	name string
	type_ BinaryTagType
}

pub struct BinaryTagExport {
pub:
	name string
	index u32
}

// LibWasm Parser/Parser.cpp::TagType::parse and TagSection::parse. The
// current source accepts only the exception tag flag zero.
fn parse_binary_tag_type(mut decoder Decoder) !BinaryTagType {
	flags := decoder.byte()!
	if flags != 0 { return error('CompileError: invalid tag flags') }
	return BinaryTagType{ type_index: decoder.u32_leb()!, flags: flags }
}

fn parse_tag_section(mut decoder Decoder) ![]BinaryTagType {
	count := decoder.u32_leb()!
	mut tags := []BinaryTagType{}
	for _ in 0 .. count { tags << parse_binary_tag_type(mut decoder)! }
	return tags
}
