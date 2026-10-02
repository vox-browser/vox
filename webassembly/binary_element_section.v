// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
module webassembly

pub enum BinaryElementMode {
	active
	passive
	declarative
}

pub struct BinaryElementSegment {
pub:
	element_type BinaryValueType
	items        []BinaryExpression
	mode         BinaryElementMode
	table_index  ?u32
	offset       ?BinaryExpression
}

// Parser.cpp::ElementSection::Element::parse: all eight source tag forms,
// including the synthetic ref.func expressions in function-index vectors.
fn parse_element_section(mut decoder Decoder) ![]BinaryElementSegment {
	count := decoder.u32_leb()!
	mut segments := []BinaryElementSegment{}
	for _ in 0 .. count {
		tag := decoder.u32_leb()!
		if tag > 7 { return error('CompileError: invalid element segment tag') }
		has_passive := tag & 1 != 0
		has_explicit_index := tag & 2 != 0
		has_expressions := tag & 4 != 0
		mut mode := BinaryElementMode.passive
		mut table_index := ?u32(none)
		mut offset := ?BinaryExpression(none)
		if has_passive {
			if has_explicit_index { mode = .declarative }
		} else {
			mode = .active
			table_index = if has_explicit_index { decoder.u32_leb()! } else { u32(0) }
			offset = parse_binary_expression(mut decoder)!
		}
		mut type_ := BinaryValueType{ kind: .function_reference, nullable: has_expressions }
		if has_passive || has_explicit_index {
			if has_expressions {
				// The source parser accepts any ValueType here; the validator
				// subsequently requires a reference type.
				type_ = parse_binary_value_type(mut decoder)!
			} else {
				if decoder.byte()! != 0 { return error('CompileError: invalid element kind') }
				type_ = BinaryValueType{ kind: .function_reference, nullable: false }
			}
		}
		item_count := decoder.u32_leb()!
		mut items := []BinaryExpression{}
		for _ in 0 .. item_count {
			if has_expressions {
				items << parse_binary_expression(mut decoder)!
			} else {
				index := decoder.u32_leb()!
				items << BinaryExpression{
					instructions: [
						BinaryInstruction{ opcode: binary_op_ref_func, arguments: BinaryIndexArgument{ kind: .function_, index: index } },
						BinaryInstruction{ opcode: binary_op_synthetic_end_expression },
					]
				}
			}
		}
		segments << BinaryElementSegment{ element_type: type_, items: items, mode: mode, table_index: table_index, offset: offset }
	}
	return segments
}
