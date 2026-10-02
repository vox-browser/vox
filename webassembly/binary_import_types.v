// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// LibWasm Parser.cpp TableType::parse, GlobalType::parse, and retained
// ImportSection::Import description records. Tag imports remain the existing
// unported WebAssembly facade boundary, rather than a fabricated descriptor.
module webassembly

pub struct BinaryTableType {
pub:
	element_type BinaryValueType
	limits       WasmLimits
}

pub struct BinaryGlobalType {
pub:
	type_    BinaryValueType
	mutable_ bool
}

pub fn (type_ BinaryValueType) is_reference() bool {
	return int(type_.kind) >= int(BinaryValueKind.function_reference)
}

fn parse_binary_table_type(mut decoder Decoder) !BinaryTableType {
	element_type := parse_binary_value_type(mut decoder)!
	if !element_type.is_reference() { return error('CompileError: invalid table element type') }
	return BinaryTableType{ element_type: element_type, limits: parse_limits(mut decoder)! }
}

fn parse_binary_global_type(mut decoder Decoder) !BinaryGlobalType {
	type_ := parse_binary_value_type(mut decoder)!
	mutable_ := decoder.byte()!
	if mutable_ > 1 { return error('CompileError: invalid global mutability') }
	return BinaryGlobalType{ type_: type_, mutable_: mutable_ == 1 }
}
