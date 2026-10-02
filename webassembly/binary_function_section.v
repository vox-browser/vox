// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause

module webassembly

// LibWasm Parser/Parser.cpp::FunctionSection::parse. These are type indices
// for the module's defined functions; imported function indices are separate.
fn parse_function_section(mut decoder Decoder) ![]u32 {
	count := decoder.u32_leb()!
	mut indices := []u32{}
	for _ in 0 .. count { indices << decoder.u32_leb()! }
	return indices
}
