// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Validator.h memory64 address helper; Validator.cpp memory size/growth/bulk.
module webassembly

fn (validator &BinaryInstructionValidator) memory_for_index(index u32) !WasmLimits {
	if u64(index) >= u64(validator.context.memories.len) {
		return error('CompileError: invalid MemoryIndex')
	}
	return validator.context.memories[index]
}

fn binary_take_memory_address(memory WasmLimits, arg BinaryMemoryArgument, mut stack BinaryValidationStack) ! {
	if memory.address_type == .i64 {
		stack.take(BinaryValueType{ kind: .i64 })!
	} else {
		if arg.offset > u64(max_u32) {
			return error('CompileError: memory op offset out of bounds')
		}
		stack.take(BinaryValueType{ kind: .i32 })!
	}
}

fn (validator &BinaryInstructionValidator) validate_data_index(index u32) ! {
	if u64(index) >= u64(validator.context.datas.len) {
		return error('CompileError: invalid DataIndex')
	}
}

fn validate_binary_memory_bulk_instruction(instruction BinaryInstruction, validator &BinaryInstructionValidator, mut stack BinaryValidationStack) !bool {
	match instruction.opcode {
		binary_op_memory_size, binary_op_memory_grow, binary_op_memory_fill {
			arg := instruction.arguments as BinaryMemoryIndexArgument
			memory := validator.memory_for_index(arg.memory_index)!
			match instruction.opcode {
				binary_op_memory_size { stack.append_type(binary_address_value_type(memory)) }
				binary_op_memory_grow {
					at := binary_address_value_type(memory)
					stack.take(at)!
					stack.append_type(at)
				}
				else {
					binary_take_memory_address(memory, BinaryMemoryArgument{}, mut stack)!
					stack.take(BinaryValueType{ kind: .i32 })!
					binary_take_memory_address(memory, BinaryMemoryArgument{}, mut stack)!
				}
			}
		}
		binary_op_memory_copy {
			args := instruction.arguments as BinaryMemoryCopyArguments
			src := validator.memory_for_index(args.src_index)!
			dst := validator.memory_for_index(args.dst_index)!
			src_at := binary_address_value_type(src)
			dst_at := binary_address_value_type(dst)
			size := BinaryValueType{ kind: if src_at.kind == .i32 || dst_at.kind == .i32 {
				BinaryValueKind.i32
			} else {
				BinaryValueKind.i64
			} }
			stack.take(size)!
			stack.take(src_at)!
			stack.take(dst_at)!
		}
		binary_op_memory_init {
			if validator.context.data_count == none {
				return error('CompileError: invalid memory.init, requires data count section')
			}
			args := instruction.arguments as BinaryMemoryInitArguments
			memory := validator.memory_for_index(args.memory_index)!
			validator.validate_data_index(args.data_index)!
			stack.take_kinds([BinaryValueKind.i32, .i32])!
			stack.take(binary_address_value_type(memory))!
		}
		binary_op_data_drop {
			if validator.context.data_count == none {
				return error('CompileError: invalid data.drop, requires data count section')
			}
			args := instruction.arguments as BinaryIndexArgument
			validator.validate_data_index(args.index)!
		}
		else { return error('instruction is outside the memory bulk validation slice') }
	}
	return false
}
