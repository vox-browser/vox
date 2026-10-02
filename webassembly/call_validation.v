// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// AbstractMachine/Validator.cpp: direct, indirect, reference and tail calls.
module webassembly

fn (validator &BinaryInstructionValidator) indirect_call_type(args BinaryIndirectCallArguments, operation string, context BinaryTypeContext) !BinaryDefinedType {
	if u64(args.table_index) >= u64(validator.context.tables.len) {
		return error('CompileError: invalid TableIndex')
	}
	validate_binary_type_index(args.type_index, validator.context.types)!
	table := validator.context.tables[args.table_index]
	if !matches_binary_reference_type(table.element_type, BinaryValueType{ kind: .function_reference }, context) {
		return error('CompileError: invalid table element type for call.indirect')
	}
	type_ := validator.context.types[args.type_index]
	if type_.kind != .function_ { return error('CompileError: invalid type for ${operation}') }
	return type_
}

fn validate_binary_call_instruction(instruction BinaryInstruction, mut validator BinaryInstructionValidator, mut stack BinaryValidationStack) !bool {
	match instruction.opcode {
		binary_op_call, binary_op_return_call {
			args := instruction.arguments as BinaryIndexArgument
			if u64(args.index) >= u64(validator.context.functions.len) {
				return error('CompileError: invalid FunctionIndex')
			}
			type_ := validator.context.functions[args.index]
			binary_take_reverse(type_.parameters, mut stack)!
			if instruction.opcode == binary_op_return_call {
				if validator.frames[0].type_.results != type_.results {
					return error('CompileError: invalid return_call target')
				}
				validator.make_current_frame_unreachable(mut stack)
			} else {
				for result in type_.results { stack.append_type(result) }
			}
		}
		binary_op_call_indirect, binary_op_return_call_indirect {
			args := instruction.arguments as BinaryIndirectCallArguments
			operation := if instruction.opcode == binary_op_call_indirect {
				'call.indirect'
			} else {
				'return_call_indirect'
			}
			type_ := validator.indirect_call_type(args, operation, stack.type_context())!
			address_kind := if instruction.opcode == binary_op_return_call_indirect {
				// Pinned source uses i32 here even for a table64 tail call.
				AddressType.i32
			} else {
				validator.context.tables[args.table_index].limits.address_type
			}
			stack.take(BinaryValueType{
				kind: if address_kind == .i32 {
					BinaryValueKind.i32
				} else {
					BinaryValueKind.i64
				}
			})!
			binary_take_reverse(type_.parameters, mut stack)!
			if instruction.opcode == binary_op_return_call_indirect {
				if validator.frames[0].type_.results != type_.results {
					return error('CompileError: invalid return_call_indirect target')
				}
				validator.make_current_frame_unreachable(mut stack)
			} else {
				for result in type_.results { stack.append_type(result) }
			}
		}
		binary_op_call_ref, binary_op_return_call_ref {
			args := instruction.arguments as BinaryIndexArgument
			validate_binary_type_index(args.index, validator.context.types)!
			type_ := validator.context.types[args.index]
			if type_.kind != .function_ {
				operation := if instruction.opcode == binary_op_call_ref {
					'call_ref'
				} else {
					'return_call_ref'
				}
				return error('CompileError: invalid type for ${operation}')
			}
			stack.take(BinaryValueType{ kind: .type_use_reference, type_index: args.index })!
			binary_take_reverse(type_.parameters, mut stack)!
			if instruction.opcode == binary_op_return_call_ref {
				returns := validator.frames[0].type_.results
				if returns.len != type_.results.len {
					return error('CompileError: invalid return_call_ref target')
				}
				for i, return_type in returns {
					entry := BinaryStackEntry{ concrete_type: type_.results[i], is_known: true }
					if !entry.matches_type(return_type) {
						return error('CompileError: invalid return_call_ref target')
					}
				}
				validator.make_current_frame_unreachable(mut stack)
			} else {
				for result in type_.results { stack.append_type(result) }
			}
		}
		else { return error('instruction is outside the call validation slice') }
	}
	return false
}
