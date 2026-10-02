// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
module webassembly

pub struct BinaryTableDefinition {
pub:
	type_ BinaryTableType
	initializer BinaryExpression
}

// Parser.cpp::TableSection::Table::parse. An ordinary table type gets the
// source's implicit nullable ref.null expression; 40 00 carries an explicit
// initializer. Evaluation and matching remain separate machine operations.
fn parse_table_section(mut decoder Decoder) ![]BinaryTableDefinition {
	count := decoder.u32_leb()!
	mut tables := []BinaryTableDefinition{}
	for _ in 0 .. count {
		tag := decoder.byte()!
		if tag == 0x40 {
			if decoder.byte()! != 0 { return error('CompileError: invalid table initializer prefix') }
			type_ := parse_binary_table_type(mut decoder)!
			initializer := parse_binary_expression(mut decoder)!
			tables << BinaryTableDefinition{ type_: type_, initializer: initializer }
		} else {
			element := parse_reference_type(mut decoder, tag)!
			limits := parse_limits(mut decoder)!
			tables << BinaryTableDefinition{
				type_: BinaryTableType{ element_type: element, limits: limits }
				initializer: BinaryExpression{ instructions: [
					BinaryInstruction{ opcode: binary_op_ref_null, arguments: BinaryValueType{ ...element, nullable: true } },
					BinaryInstruction{ opcode: binary_op_synthetic_end_expression },
				] }
			}
		}
	}
	return tables
}
