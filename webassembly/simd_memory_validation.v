// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Validator.cpp SIMD loads/stores, including pinned memory64/offset omissions.
module webassembly

fn binary_check_simd_alignment(arg BinaryMemoryArgument, maximum i32) ! {
	if arg.align > 64 { return error('CompileError: memory op alignment value out of bounds') }
	// Source SIMD lane/splat/zero paths use the native int literal, unlike
	// scalar and full-vector accesses, which use 1ull. Keep that distinction.
	if (i32(1) << arg.align) > maximum {
		return error('CompileError: memory op alignment out of bounds')
	}
}

fn validate_binary_simd_memory_instruction(instruction BinaryInstruction, validator &BinaryInstructionValidator, mut stack BinaryValidationStack) !bool {
	match instruction.opcode {
		binary_op_v128_load8x8_s, binary_op_v128_load8x8_u,
		binary_op_v128_load16x4_s, binary_op_v128_load16x4_u,
		binary_op_v128_load32x2_s, binary_op_v128_load32x2_u,
		binary_op_v128_load8_splat, binary_op_v128_load16_splat,
		binary_op_v128_load32_splat, binary_op_v128_load64_splat {
			arg := instruction.arguments as BinaryMemoryArgument
			validator.memory_for_index(arg.memory_index)!
			maximum := match instruction.opcode {
				binary_op_v128_load8_splat { i32(8 / 8) }
				binary_op_v128_load16_splat { i32(16 / 8) }
				binary_op_v128_load32_splat { i32(32 / 8) }
				binary_op_v128_load64_splat { i32(64 / 8) }
				binary_op_v128_load8x8_s, binary_op_v128_load8x8_u { i32(8 * 8 / 8) }
				binary_op_v128_load16x4_s, binary_op_v128_load16x4_u { i32(16 * 4 / 8) }
				else { i32(32 * 2 / 8) }
			}
			binary_check_simd_alignment(arg, maximum)!
			// Source validates memory existence then directly takes i32; it
			// neither takes the memory64 type nor checks the memory32 offset.
			stack.take_and_put([BinaryValueKind.i32], .v128)!
		}
		binary_op_v128_store {
			arg := instruction.arguments as BinaryMemoryArgument
			validator.memory_for_index(arg.memory_index)!
			if arg.align > 64 {
				return error('CompileError: memory op alignment value out of bounds')
			}
			if (u64(1) << arg.align) > 16 {
				return error('CompileError: memory op alignment out of bounds')
			}
			// This pinned body also directly takes i32 without its offset check.
			stack.take_kinds([BinaryValueKind.v128, .i32])!
		}
		binary_op_v128_load32_zero, binary_op_v128_load64_zero {
			arg := instruction.arguments as BinaryMemoryArgument
			memory := validator.memory_for_index(arg.memory_index)!
			maximum := if instruction.opcode == binary_op_v128_load32_zero {
				i32(32 / 8)
			} else {
				i32(64 / 8)
			}
			binary_check_simd_alignment(arg, maximum)!
			binary_take_memory_address(memory, arg, mut stack)!
			stack.append_type(BinaryValueType{ kind: .v128 })
		}
		binary_op_v128_load8_lane, binary_op_v128_load16_lane,
		binary_op_v128_load32_lane, binary_op_v128_load64_lane,
		binary_op_v128_store8_lane, binary_op_v128_store16_lane,
		binary_op_v128_store32_lane, binary_op_v128_store64_lane {
			arg := instruction.arguments as BinaryMemoryLaneArgument
			n := match instruction.opcode {
				binary_op_v128_load8_lane, binary_op_v128_store8_lane { u32(8) }
				binary_op_v128_load16_lane, binary_op_v128_store16_lane { u32(16) }
				binary_op_v128_load32_lane, binary_op_v128_store32_lane { u32(32) }
				else { u32(64) }
			}
			if u32(arg.lane) >= 128 / n { return error('CompileError: lane index out of bounds') }
			memory := validator.memory_for_index(arg.memory.memory_index)!
			binary_check_simd_alignment(arg.memory, i32(n / 8))!
			stack.take(BinaryValueType{ kind: .v128 })!
			binary_take_memory_address(memory, arg.memory, mut stack)!
			if instruction.opcode in [binary_op_v128_load8_lane, binary_op_v128_load16_lane,
				binary_op_v128_load32_lane, binary_op_v128_load64_lane] {
				stack.append_type(BinaryValueType{ kind: .v128 })
			}
		}
		else { return error('instruction is outside the SIMD memory validation slice') }
	}
	return false
}
