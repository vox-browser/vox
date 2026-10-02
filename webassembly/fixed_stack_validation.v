// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Generated direct statement translations; no effects inferred from names.
// Ladybird 963d46a829f3e1b79f44dba9d02afb70654300fa, AbstractMachine/Validator.cpp
// Source SHA256: 35726520480275678490d4b4aaf600a2d1b33480d79eac99ab9b5c91d1bc405f
// Regenerate with tools/generate_wasm_fixed_validation.py.
module webassembly

fn validate_binary_fixed_stack_instruction(instruction BinaryInstruction, mut stack BinaryValidationStack) !bool {
	match instruction.opcode {
		binary_op_i32_const {
			stack.append_type(BinaryValueType{ kind: .i32 })
			return true
		}
		binary_op_i64_const {
			stack.append_type(BinaryValueType{ kind: .i64 })
			return true
		}
		binary_op_f32_const {
			stack.append_type(BinaryValueType{ kind: .f32 })
			return true
		}
		binary_op_f64_const {
			stack.append_type(BinaryValueType{ kind: .f64 })
			return true
		}
		binary_op_i32_clz, binary_op_i32_ctz, binary_op_i32_popcnt, binary_op_i32_extend16_s,
		binary_op_i32_extend8_s {
			stack.take_and_put([BinaryValueKind.i32], .i32)!
			return false
		}
		binary_op_i64_clz, binary_op_i64_ctz, binary_op_i64_popcnt, binary_op_i64_extend32_s,
		binary_op_i64_extend16_s, binary_op_i64_extend8_s {
			stack.take_and_put([BinaryValueKind.i64], .i64)!
			return false
		}
		binary_op_f32_abs, binary_op_f32_neg, binary_op_f32_sqrt, binary_op_f32_ceil,
		binary_op_f32_floor, binary_op_f32_trunc, binary_op_f32_nearest {
			stack.take_and_put([BinaryValueKind.f32], .f32)!
			return false
		}
		binary_op_f64_abs, binary_op_f64_neg, binary_op_f64_sqrt, binary_op_f64_ceil,
		binary_op_f64_floor, binary_op_f64_trunc, binary_op_f64_nearest {
			stack.take_and_put([BinaryValueKind.f64], .f64)!
			return false
		}
		binary_op_i32_add, binary_op_i32_sub, binary_op_i32_mul {
			stack.take_kinds([BinaryValueKind.i32, .i32])!
			stack.append_type(BinaryValueType{ kind: .i32 })
			return true
		}
		binary_op_i32_divs, binary_op_i32_divu, binary_op_i32_rems, binary_op_i32_remu,
		binary_op_i32_and, binary_op_i32_or, binary_op_i32_xor, binary_op_i32_shl,
		binary_op_i32_shrs, binary_op_i32_shru, binary_op_i32_rotl, binary_op_i32_rotr,
		binary_op_i32_eq, binary_op_i32_ne, binary_op_i32_lts, binary_op_i32_ltu,
		binary_op_i32_gts, binary_op_i32_gtu, binary_op_i32_les, binary_op_i32_leu,
		binary_op_i32_ges, binary_op_i32_geu {
			stack.take_kinds([BinaryValueKind.i32, .i32])!
			stack.append_type(BinaryValueType{ kind: .i32 })
			return false
		}
		binary_op_i64_add, binary_op_i64_sub, binary_op_i64_mul {
			stack.take_kinds([BinaryValueKind.i64, .i64])!
			stack.append_type(BinaryValueType{ kind: .i64 })
			return true
		}
		binary_op_i64_divs, binary_op_i64_divu, binary_op_i64_rems, binary_op_i64_remu,
		binary_op_i64_and, binary_op_i64_or, binary_op_i64_xor, binary_op_i64_shl,
		binary_op_i64_shrs, binary_op_i64_shru, binary_op_i64_rotl, binary_op_i64_rotr {
			stack.take_kinds([BinaryValueKind.i64, .i64])!
			stack.append_type(BinaryValueType{ kind: .i64 })
			return false
		}
		binary_op_f32_add, binary_op_f32_sub, binary_op_f32_mul, binary_op_f32_div,
		binary_op_f32_min, binary_op_f32_max, binary_op_f32_copysign {
			stack.take_kinds([BinaryValueKind.f32, .f32])!
			stack.append_type(BinaryValueType{ kind: .f32 })
			return false
		}
		binary_op_f64_add, binary_op_f64_sub, binary_op_f64_mul, binary_op_f64_div,
		binary_op_f64_min, binary_op_f64_max, binary_op_f64_copysign {
			stack.take_kinds([BinaryValueKind.f64, .f64])!
			stack.append_type(BinaryValueType{ kind: .f64 })
			return false
		}
		binary_op_i32_eqz {
			stack.take_kinds([BinaryValueKind.i32])!
			stack.append_type(BinaryValueType{ kind: .i32 })
			return false
		}
		binary_op_i64_eqz {
			stack.take_kinds([BinaryValueKind.i64])!
			stack.append_type(BinaryValueType{ kind: .i32 })
			return false
		}
		binary_op_i64_eq, binary_op_i64_ne, binary_op_i64_lts, binary_op_i64_ltu,
		binary_op_i64_gts, binary_op_i64_gtu, binary_op_i64_les, binary_op_i64_leu,
		binary_op_i64_ges, binary_op_i64_geu {
			stack.take_kinds([BinaryValueKind.i64, .i64])!
			stack.append_type(BinaryValueType{ kind: .i32 })
			return false
		}
		binary_op_f32_eq, binary_op_f32_ne, binary_op_f32_lt, binary_op_f32_le, binary_op_f32_gt,
		binary_op_f32_ge {
			stack.take_kinds([BinaryValueKind.f32, .f32])!
			stack.append_type(BinaryValueType{ kind: .i32 })
			return false
		}
		binary_op_f64_eq, binary_op_f64_ne, binary_op_f64_lt, binary_op_f64_le, binary_op_f64_gt,
		binary_op_f64_ge {
			stack.take_kinds([BinaryValueKind.f64, .f64])!
			stack.append_type(BinaryValueType{ kind: .i32 })
			return false
		}
		binary_op_i32_wrap_i64 {
			stack.take_and_put([BinaryValueKind.i64], .i32)!
			return false
		}
		binary_op_i64_extend_si32, binary_op_i64_extend_ui32 {
			stack.take_and_put([BinaryValueKind.i32], .i64)!
			return false
		}
		binary_op_i32_trunc_sf32, binary_op_i32_trunc_uf32, binary_op_i32_trunc_sat_f32_s,
		binary_op_i32_trunc_sat_f32_u, binary_op_i32_reinterpret_f32 {
			stack.take_and_put([BinaryValueKind.f32], .i32)!
			return false
		}
		binary_op_i32_trunc_sf64, binary_op_i32_trunc_uf64, binary_op_i32_trunc_sat_f64_s,
		binary_op_i32_trunc_sat_f64_u {
			stack.take_and_put([BinaryValueKind.f64], .i32)!
			return false
		}
		binary_op_i64_trunc_sf32, binary_op_i64_trunc_uf32, binary_op_i64_trunc_sat_f32_s,
		binary_op_i64_trunc_sat_f32_u {
			stack.take_and_put([BinaryValueKind.f32], .i64)!
			return false
		}
		binary_op_i64_trunc_sf64, binary_op_i64_trunc_uf64, binary_op_i64_trunc_sat_f64_s,
		binary_op_i64_trunc_sat_f64_u, binary_op_i64_reinterpret_f64 {
			stack.take_and_put([BinaryValueKind.f64], .i64)!
			return false
		}
		binary_op_f32_convert_si32, binary_op_f32_convert_ui32, binary_op_f32_reinterpret_i32 {
			stack.take_and_put([BinaryValueKind.i32], .f32)!
			return false
		}
		binary_op_f32_convert_si64, binary_op_f32_convert_ui64 {
			stack.take_and_put([BinaryValueKind.i64], .f32)!
			return false
		}
		binary_op_f64_convert_si32, binary_op_f64_convert_ui32 {
			stack.take_and_put([BinaryValueKind.i32], .f64)!
			return false
		}
		binary_op_f64_convert_si64, binary_op_f64_convert_ui64, binary_op_f64_reinterpret_i64 {
			stack.take_and_put([BinaryValueKind.i64], .f64)!
			return false
		}
		binary_op_f32_demote_f64 {
			stack.take_and_put([BinaryValueKind.f64], .f32)!
			return false
		}
		binary_op_f64_promote_f32 {
			stack.take_and_put([BinaryValueKind.f32], .f64)!
			return false
		}
		binary_op_nop {
			return false
		}
		binary_op_v128_const {
			stack.append_type(BinaryValueType{ kind: .v128 })
			return true
		}
		binary_op_synthetic_end_expression {
			return true
		}
		else { return error('instruction is outside the fixed-stack validation slice') }
	}
}
