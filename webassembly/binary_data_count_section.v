// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
module webassembly

pub struct BinaryDataCountSection {
pub:
	count ?u32
}

// Parser.cpp::DataCountSection::parse retains an optional count. Preserve its
// EOF error branch, including a failed LEB read that exhausted the section;
// this is source parser behavior, not proof of module/instruction validity.
fn parse_data_count_section(mut decoder Decoder) !BinaryDataCountSection {
	count := decoder.u32_leb() or {
		if decoder.offset == decoder.bytes.len { return BinaryDataCountSection{} }
		return error('CompileError: expected data count')
	}
	return BinaryDataCountSection{ count: count }
}
