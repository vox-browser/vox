// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
module webassembly

pub enum BinaryDataMode {
	active
	passive
}

pub struct BinaryDataSegment {
pub:
	mode         BinaryDataMode
	memory_index ?u32
	init         []u8
pub mut:
	offset ?BinaryExpression
}

// Parser/Parser.cpp::DataSection::{Data,parse}: active implicit/explicit
// memory indices and passive initialization bytes retain the source records.
fn parse_data_section(mut decoder Decoder) ![]BinaryDataSegment {
	count := decoder.u32_leb()!
	mut segments := []BinaryDataSegment{}
	for _ in 0 .. count {
		tag := decoder.u32_leb()!
		if tag > 2 { return error('CompileError: invalid data segment tag') }
		if tag == 1 {
			segments << BinaryDataSegment{ mode: .passive, init: decoder.byte_vector()! }
		} else {
			index := if tag == 2 { decoder.u32_leb()! } else { u32(0) }
			offset := parse_binary_expression(mut decoder)!
			init := decoder.byte_vector()!
			segments << BinaryDataSegment{ mode: .active, memory_index: index, offset: offset, init: init }
		}
	}
	return segments
}
