// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
module webassembly

pub struct BinaryGlobalDefinition {
pub:
	type_ BinaryGlobalType
pub mut:
	initializer BinaryExpression
}

// Parser/Parser.cpp::GlobalSection::{Global,parse}: preserve every actual
// initializer instruction; type checking and evaluation belong to the machine.
fn parse_global_section(mut decoder Decoder) ![]BinaryGlobalDefinition {
	count := decoder.u32_leb()!
	mut globals := []BinaryGlobalDefinition{}
	for _ in 0 .. count {
		type_ := parse_binary_global_type(mut decoder)!
		initializer := parse_binary_expression(mut decoder)!
		globals << BinaryGlobalDefinition{ type_: type_, initializer: initializer }
	}
	return globals
}
