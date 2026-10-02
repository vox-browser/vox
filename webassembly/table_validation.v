// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// AbstractMachine/Validator.cpp: table access, growth and bulk operations.
module webassembly

fn binary_address_value_type(limits WasmLimits) BinaryValueType {
	return BinaryValueType{ kind: if limits.address_type == .i32 {
		BinaryValueKind.i32
	} else {
		BinaryValueKind.i64
	} }
}

fn (validator &BinaryInstructionValidator) table_for_index(index u32) !BinaryTableType {
	if u64(index) >= u64(validator.context.tables.len) {
		return error('CompileError: invalid TableIndex')
	}
	return validator.context.tables[index]
}

fn (validator &BinaryInstructionValidator) validate_element_index(index u32) ! {
	if u64(index) >= u64(validator.context.elements.len) {
		return error('CompileError: invalid ElementIndex')
	}
}

fn validate_binary_table_instruction(instruction BinaryInstruction, validator &BinaryInstructionValidator, mut stack BinaryValidationStack) !bool {
	match instruction.opcode {
		binary_op_table_get, binary_op_table_set, binary_op_table_size, binary_op_table_grow,
		binary_op_table_fill {
			args := instruction.arguments as BinaryIndexArgument
			table := validator.table_for_index(args.index)!
			at := binary_address_value_type(table.limits)
			match instruction.opcode {
				binary_op_table_get {
					stack.take(at)!
					stack.append_type(table.element_type)
				}
				binary_op_table_set {
					stack.take(table.element_type)!
					stack.take(at)!
				}
				binary_op_table_size { stack.append_type(at) }
				binary_op_table_grow {
					stack.take(at)!
					stack.take(table.element_type)!
					stack.append_type(at)
				}
				else {
					stack.take(at)!
					stack.take(table.element_type)!
					stack.take(at)!
				}
			}
		}
		binary_op_table_copy {
			args := instruction.arguments as BinaryTableTableArguments
			lhs := validator.table_for_index(args.lhs)!
			rhs := validator.table_for_index(args.rhs)!
			if !matches_binary_reference_type(rhs.element_type, lhs.element_type, stack.type_context()) {
				return error('CompileError: non-conforming table.copy types')
			}
			lhs_at := binary_address_value_type(lhs.limits)
			rhs_at := binary_address_value_type(rhs.limits)
			size := BinaryValueType{ kind: if lhs_at.kind == .i32 || rhs_at.kind == .i32 {
				BinaryValueKind.i32
			} else {
				BinaryValueKind.i64
			} }
			stack.take(size)!
			stack.take(rhs_at)!
			stack.take(lhs_at)!
		}
		binary_op_table_init {
			args := instruction.arguments as BinaryTableElementArguments
			table := validator.table_for_index(args.table_index)!
			validator.validate_element_index(args.element_index)!
			if !matches_binary_reference_type(validator.context.elements[args.element_index], table.element_type, stack.type_context()) {
				return error('CompileError: non-conforming table.init types')
			}
			stack.take_kinds([BinaryValueKind.i32, .i32])!
			stack.take(binary_address_value_type(table.limits))!
		}
		binary_op_elem_drop {
			args := instruction.arguments as BinaryIndexArgument
			validator.validate_element_index(args.index)!
		}
		else { return error('instruction is outside the table validation slice') }
	}
	return false
}
