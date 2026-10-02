// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Generated complete source memory access bodies; no name inference.
// Ladybird 963d46a829f3e1b79f44dba9d02afb70654300fa, AbstractMachine/Validator.cpp
// Source SHA256: 35726520480275678490d4b4aaf600a2d1b33480d79eac99ab9b5c91d1bc405f
// Regenerate with tools/generate_wasm_memory_validation.py.
module webassembly

fn validate_binary_memory_access_instruction(instruction BinaryInstruction, validator &BinaryInstructionValidator, mut stack BinaryValidationStack) !bool {
	match instruction.opcode {
		binary_op_i32_load {
			arg := instruction.arguments as BinaryMemoryArgument
			memory := validator.memory_for_index(arg.memory_index)!
			if arg.align > 64 {
				return error('CompileError: memory op alignment value out of bounds')
			}
			if (u64(1) << arg.align) > 4 {
				return error('CompileError: memory op alignment out of bounds')
			}
			binary_take_memory_address(memory, arg, mut stack)!
			stack.append_type(BinaryValueType{ kind: .i32 })
			return false
		}
		binary_op_i64_load {
			arg := instruction.arguments as BinaryMemoryArgument
			memory := validator.memory_for_index(arg.memory_index)!
			if arg.align > 64 {
				return error('CompileError: memory op alignment value out of bounds')
			}
			if (u64(1) << arg.align) > 8 {
				return error('CompileError: memory op alignment out of bounds')
			}
			binary_take_memory_address(memory, arg, mut stack)!
			stack.append_type(BinaryValueType{ kind: .i64 })
			return false
		}
		binary_op_f32_load {
			arg := instruction.arguments as BinaryMemoryArgument
			memory := validator.memory_for_index(arg.memory_index)!
			if arg.align > 64 {
				return error('CompileError: memory op alignment value out of bounds')
			}
			if (u64(1) << arg.align) > 4 {
				return error('CompileError: memory op alignment out of bounds')
			}
			binary_take_memory_address(memory, arg, mut stack)!
			stack.append_type(BinaryValueType{ kind: .f32 })
			return false
		}
		binary_op_f64_load {
			arg := instruction.arguments as BinaryMemoryArgument
			memory := validator.memory_for_index(arg.memory_index)!
			if arg.align > 64 {
				return error('CompileError: memory op alignment value out of bounds')
			}
			if (u64(1) << arg.align) > 8 {
				return error('CompileError: memory op alignment out of bounds')
			}
			binary_take_memory_address(memory, arg, mut stack)!
			stack.append_type(BinaryValueType{ kind: .f64 })
			return false
		}
		binary_op_i32_load16_s, binary_op_i32_load16_u {
			arg := instruction.arguments as BinaryMemoryArgument
			memory := validator.memory_for_index(arg.memory_index)!
			if arg.align > 64 {
				return error('CompileError: memory op alignment value out of bounds')
			}
			if (u64(1) << arg.align) > 2 {
				return error('CompileError: memory op alignment out of bounds')
			}
			binary_take_memory_address(memory, arg, mut stack)!
			stack.append_type(BinaryValueType{ kind: .i32 })
			return false
		}
		binary_op_i32_load8_s, binary_op_i32_load8_u {
			arg := instruction.arguments as BinaryMemoryArgument
			memory := validator.memory_for_index(arg.memory_index)!
			if arg.align > 64 {
				return error('CompileError: memory op alignment value out of bounds')
			}
			if (u64(1) << arg.align) > 1 {
				return error('CompileError: memory op alignment out of bounds')
			}
			binary_take_memory_address(memory, arg, mut stack)!
			stack.append_type(BinaryValueType{ kind: .i32 })
			return false
		}
		binary_op_i64_load32_s, binary_op_i64_load32_u {
			arg := instruction.arguments as BinaryMemoryArgument
			memory := validator.memory_for_index(arg.memory_index)!
			if arg.align > 64 {
				return error('CompileError: memory op alignment value out of bounds')
			}
			if (u64(1) << arg.align) > 4 {
				return error('CompileError: memory op alignment out of bounds')
			}
			binary_take_memory_address(memory, arg, mut stack)!
			stack.append_type(BinaryValueType{ kind: .i64 })
			return false
		}
		binary_op_i64_load16_s, binary_op_i64_load16_u {
			arg := instruction.arguments as BinaryMemoryArgument
			memory := validator.memory_for_index(arg.memory_index)!
			if arg.align > 64 {
				return error('CompileError: memory op alignment value out of bounds')
			}
			if (u64(1) << arg.align) > 2 {
				return error('CompileError: memory op alignment out of bounds')
			}
			binary_take_memory_address(memory, arg, mut stack)!
			stack.append_type(BinaryValueType{ kind: .i64 })
			return false
		}
		binary_op_i64_load8_s, binary_op_i64_load8_u {
			arg := instruction.arguments as BinaryMemoryArgument
			memory := validator.memory_for_index(arg.memory_index)!
			if arg.align > 64 {
				return error('CompileError: memory op alignment value out of bounds')
			}
			if (u64(1) << arg.align) > 1 {
				return error('CompileError: memory op alignment out of bounds')
			}
			binary_take_memory_address(memory, arg, mut stack)!
			stack.append_type(BinaryValueType{ kind: .i64 })
			return false
		}
		binary_op_i32_store {
			arg := instruction.arguments as BinaryMemoryArgument
			memory := validator.memory_for_index(arg.memory_index)!
			if arg.align > 64 {
				return error('CompileError: memory op alignment value out of bounds')
			}
			if (u64(1) << arg.align) > 4 {
				return error('CompileError: memory op alignment out of bounds')
			}
			stack.take(BinaryValueType{ kind: .i32 })!
			binary_take_memory_address(memory, arg, mut stack)!
			return false
		}
		binary_op_i64_store {
			arg := instruction.arguments as BinaryMemoryArgument
			memory := validator.memory_for_index(arg.memory_index)!
			if arg.align > 64 {
				return error('CompileError: memory op alignment value out of bounds')
			}
			if (u64(1) << arg.align) > 8 {
				return error('CompileError: memory op alignment out of bounds')
			}
			stack.take(BinaryValueType{ kind: .i64 })!
			binary_take_memory_address(memory, arg, mut stack)!
			return false
		}
		binary_op_f32_store {
			arg := instruction.arguments as BinaryMemoryArgument
			memory := validator.memory_for_index(arg.memory_index)!
			if arg.align > 64 {
				return error('CompileError: memory op alignment value out of bounds')
			}
			if (u64(1) << arg.align) > 4 {
				return error('CompileError: memory op alignment out of bounds')
			}
			stack.take(BinaryValueType{ kind: .f32 })!
			binary_take_memory_address(memory, arg, mut stack)!
			return false
		}
		binary_op_f64_store {
			arg := instruction.arguments as BinaryMemoryArgument
			memory := validator.memory_for_index(arg.memory_index)!
			if arg.align > 64 {
				return error('CompileError: memory op alignment value out of bounds')
			}
			if (u64(1) << arg.align) > 8 {
				return error('CompileError: memory op alignment out of bounds')
			}
			stack.take(BinaryValueType{ kind: .f64 })!
			binary_take_memory_address(memory, arg, mut stack)!
			return false
		}
		binary_op_i32_store16 {
			arg := instruction.arguments as BinaryMemoryArgument
			memory := validator.memory_for_index(arg.memory_index)!
			if arg.align > 64 {
				return error('CompileError: memory op alignment value out of bounds')
			}
			if (u64(1) << arg.align) > 2 {
				return error('CompileError: memory op alignment out of bounds')
			}
			stack.take(BinaryValueType{ kind: .i32 })!
			binary_take_memory_address(memory, arg, mut stack)!
			return false
		}
		binary_op_i32_store8 {
			arg := instruction.arguments as BinaryMemoryArgument
			memory := validator.memory_for_index(arg.memory_index)!
			if arg.align > 64 {
				return error('CompileError: memory op alignment value out of bounds')
			}
			if (u64(1) << arg.align) > 1 {
				return error('CompileError: memory op alignment out of bounds')
			}
			stack.take(BinaryValueType{ kind: .i32 })!
			binary_take_memory_address(memory, arg, mut stack)!
			return false
		}
		binary_op_i64_store32 {
			arg := instruction.arguments as BinaryMemoryArgument
			memory := validator.memory_for_index(arg.memory_index)!
			if arg.align > 64 {
				return error('CompileError: memory op alignment value out of bounds')
			}
			if (u64(1) << arg.align) > 4 {
				return error('CompileError: memory op alignment out of bounds')
			}
			stack.take(BinaryValueType{ kind: .i64 })!
			binary_take_memory_address(memory, arg, mut stack)!
			return false
		}
		binary_op_i64_store16 {
			arg := instruction.arguments as BinaryMemoryArgument
			memory := validator.memory_for_index(arg.memory_index)!
			if arg.align > 64 {
				return error('CompileError: memory op alignment value out of bounds')
			}
			if (u64(1) << arg.align) > 2 {
				return error('CompileError: memory op alignment out of bounds')
			}
			stack.take(BinaryValueType{ kind: .i64 })!
			binary_take_memory_address(memory, arg, mut stack)!
			return false
		}
		binary_op_i64_store8 {
			arg := instruction.arguments as BinaryMemoryArgument
			memory := validator.memory_for_index(arg.memory_index)!
			if arg.align > 64 {
				return error('CompileError: memory op alignment value out of bounds')
			}
			if (u64(1) << arg.align) > 1 {
				return error('CompileError: memory op alignment out of bounds')
			}
			stack.take(BinaryValueType{ kind: .i64 })!
			binary_take_memory_address(memory, arg, mut stack)!
			return false
		}
		binary_op_v128_load {
			arg := instruction.arguments as BinaryMemoryArgument
			memory := validator.memory_for_index(arg.memory_index)!
			if arg.align > 64 {
				return error('CompileError: memory op alignment value out of bounds')
			}
			if (u64(1) << arg.align) > 16 {
				return error('CompileError: memory op alignment out of bounds')
			}
			binary_take_memory_address(memory, arg, mut stack)!
			stack.append_type(BinaryValueType{ kind: .v128 })
			return false
		}
		else { return error('instruction is outside the memory access validation slice') }
	}
}
