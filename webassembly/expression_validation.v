// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
module webassembly

// Each scalar/unknown value takes one 64-bit slot; v128 takes two.
const binary_max_function_stack_slots = 1 << 20

pub struct BinaryExpressionTypeResult {
pub:
	result_types []BinaryStackEntry
	is_constant  bool
}

// AbstractMachine/Validator.cpp::validate(Expression): the validation pass,
// including instruction metadata and the peak stack hint. The following native
// try_compile_instructions/Cranelift compilation remains a separate port slice.
pub fn (mut validator BinaryInstructionValidator) validate_expression(mut expression BinaryExpression, result_types []BinaryValueType) !BinaryExpressionTypeResult {
	if validator.frames.len == 0 {
		validator.frames << BinaryValidationFrame{
			type_:        BinaryDefinedType{ kind: .function_, results: result_types.clone() }
			kind:         .function_
			initial_size: 0
		}
	}
	mut stack := BinaryValidationStack.create(&validator, BinaryTypeContext{ types: validator.context.canonical_types })
	mut is_constant_expression := true
	for mut instruction in expression.instructions {
		is_constant := validator.validate_instruction(mut instruction, mut stack)!
		if stack.slot_height() > binary_max_function_stack_slots {
			return error('CompileError: operand stack too deep')
		}
		is_constant_expression = is_constant_expression && is_constant
	}
	binary_take_reverse(result_types, mut stack)!
	for type_ in result_types { stack.append_type(type_) }
	validator.frames.pop()
	expression.set_stack_usage_hint(uint(stack.maximum_known_size()))
	assert validator.frames.len == 0
	return BinaryExpressionTypeResult{ result_types: stack.release_vector(), is_constant: is_constant_expression }
}
