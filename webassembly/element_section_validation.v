// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
module webassembly

// AbstractMachine/Validator.cpp::validate(ElementSection).
fn (mut validator BinaryInstructionValidator) validate_element_section(mut segments []BinaryElementSegment) ! {
	for mut segment in segments {
		validate_binary_value_type(segment.element_type, validator.context.types)!
		if !segment.element_type.is_reference() {
			return error('CompileError: invalid element reference type')
		}
		if segment.mode == .active {
			index := segment.table_index or { panic('missing parsed active table index') }
			table := validator.table_for_index(index)!
			if !matches_binary_value_type(segment.element_type, table.element_type, BinaryTypeContext{ types: validator.context.canonical_types }) {
				return error('CompileError: invalid active element reference type')
			}
			at := binary_address_value_type(table.limits)
			mut expression := segment.offset or { panic('missing parsed active element offset') }
			result := validator.validate_expression(mut expression, [at])!
			segment.offset = expression
			if !result.is_constant {
				return error('CompileError: invalid active element initializer')
			}
			if result.result_types.len != 1 || !result.result_types[0].is_of_kind(at.kind) {
				return error('CompileError: invalid active element initializer type')
			}
		}
		for mut expression in segment.items {
			if expression.instructions.len == 0 { continue }
			result := validator.validate_expression(mut expression, [segment.element_type])!
			if !result.is_constant { return error('CompileError: invalid element initializer') }
			if result.result_types.len != 1 {
				return error('CompileError: invalid element initializer type')
			}
		}
	}
}
