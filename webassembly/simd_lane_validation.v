// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Validator.cpp Shape/unpacked/dimensions and SIMD shuffle/splat/lane handlers.
module webassembly

enum BinarySimdShape {
	i8x16
	i16x8
	i32x4
	i64x2
	f32x4
	f64x2
}

fn (shape BinarySimdShape) unpacked() BinaryValueKind {
	return match shape {
		.i8x16, .i16x8, .i32x4 { BinaryValueKind.i32 }
		.i64x2 { BinaryValueKind.i64 }
		.f32x4 { BinaryValueKind.f32 }
		.f64x2 { BinaryValueKind.f64 }
	}
}

fn (shape BinarySimdShape) dimensions() u8 {
	return match shape {
		.i8x16 { u8(16) }
		.i16x8 { u8(8) }
		.i32x4, .f32x4 { u8(4) }
		.i64x2, .f64x2 { u8(2) }
	}
}

fn validate_binary_simd_lane_instruction(instruction BinaryInstruction, mut stack BinaryValidationStack) !bool {
	if instruction.opcode == binary_op_i8x16_shuffle {
		arg := instruction.arguments as BinaryShuffleArgument
		for lane in arg.lanes {
			if lane >= 32 { return error('CompileError: shuffle lane out of bounds') }
		}
		stack.take_and_put([BinaryValueKind.v128, .v128], .v128)!
		return false
	}
	shape := match instruction.opcode {
		binary_op_i8x16_splat, binary_op_i8x16_extract_lane_s, binary_op_i8x16_extract_lane_u,
		binary_op_i8x16_replace_lane {
			BinarySimdShape.i8x16
		}
		binary_op_i16x8_splat, binary_op_i16x8_extract_lane_s, binary_op_i16x8_extract_lane_u,
		binary_op_i16x8_replace_lane {
			BinarySimdShape.i16x8
		}
		binary_op_i32x4_splat, binary_op_i32x4_extract_lane, binary_op_i32x4_replace_lane {
			BinarySimdShape.i32x4
		}
		binary_op_i64x2_splat, binary_op_i64x2_extract_lane, binary_op_i64x2_replace_lane {
			BinarySimdShape.i64x2
		}
		binary_op_f32x4_splat, binary_op_f32x4_extract_lane, binary_op_f32x4_replace_lane {
			BinarySimdShape.f32x4
		}
		binary_op_f64x2_splat, binary_op_f64x2_extract_lane, binary_op_f64x2_replace_lane {
			BinarySimdShape.f64x2
		}
		else { return error('instruction is outside the SIMD lane validation slice') }
	}
	if instruction.opcode in [binary_op_i8x16_splat, binary_op_i16x8_splat, binary_op_i32x4_splat,
		binary_op_i64x2_splat, binary_op_f32x4_splat, binary_op_f64x2_splat] {
		stack.take_and_put([shape.unpacked()], .v128)!
		return false
	}
	arg := instruction.arguments as BinaryLaneArgument
	if arg.lane >= shape.dimensions() { return error('CompileError: extract lane out of bounds') }
	if instruction.opcode in [binary_op_i8x16_replace_lane, binary_op_i16x8_replace_lane,
		binary_op_i32x4_replace_lane, binary_op_i64x2_replace_lane, binary_op_f32x4_replace_lane,
		binary_op_f64x2_replace_lane] {
		stack.take_and_put([shape.unpacked(), BinaryValueKind.v128], .v128)!
	} else {
		stack.take_and_put([BinaryValueKind.v128], shape.unpacked())!
	}
	return false
}
