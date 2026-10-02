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
		binary_op_i8x16_swizzle, binary_op_i8x16_eq, binary_op_i8x16_ne, binary_op_i8x16_lt_s,
		binary_op_i8x16_lt_u, binary_op_i8x16_gt_s, binary_op_i8x16_gt_u, binary_op_i8x16_le_s,
		binary_op_i8x16_le_u, binary_op_i8x16_ge_s, binary_op_i8x16_ge_u, binary_op_i16x8_eq,
		binary_op_i16x8_ne, binary_op_i16x8_lt_s, binary_op_i16x8_lt_u, binary_op_i16x8_gt_s,
		binary_op_i16x8_gt_u, binary_op_i16x8_le_s, binary_op_i16x8_le_u, binary_op_i16x8_ge_s,
		binary_op_i16x8_ge_u, binary_op_i32x4_eq, binary_op_i32x4_ne, binary_op_i32x4_lt_s,
		binary_op_i32x4_lt_u, binary_op_i32x4_gt_s, binary_op_i32x4_gt_u, binary_op_i32x4_le_s,
		binary_op_i32x4_le_u, binary_op_i32x4_ge_s, binary_op_i32x4_ge_u, binary_op_f32x4_eq,
		binary_op_f32x4_ne, binary_op_f32x4_lt, binary_op_f32x4_gt, binary_op_f32x4_le,
		binary_op_f32x4_ge, binary_op_f64x2_eq, binary_op_f64x2_ne, binary_op_f64x2_lt,
		binary_op_f64x2_gt, binary_op_f64x2_le, binary_op_f64x2_ge, binary_op_v128_and,
		binary_op_v128_andnot, binary_op_v128_or, binary_op_v128_xor,
		binary_op_i8x16_narrow_i16x8_s, binary_op_i8x16_narrow_i16x8_u, binary_op_i8x16_add,
		binary_op_i8x16_add_sat_s, binary_op_i8x16_add_sat_u, binary_op_i8x16_sub,
		binary_op_i8x16_sub_sat_s, binary_op_i8x16_sub_sat_u, binary_op_i8x16_min_s,
		binary_op_i8x16_min_u, binary_op_i8x16_max_s, binary_op_i8x16_max_u,
		binary_op_i8x16_avgr_u, binary_op_i16x8_q15mulr_sat_s, binary_op_i16x8_narrow_i32x4_s,
		binary_op_i16x8_narrow_i32x4_u, binary_op_i16x8_add, binary_op_i16x8_add_sat_s,
		binary_op_i16x8_add_sat_u, binary_op_i16x8_sub, binary_op_i16x8_sub_sat_s,
		binary_op_i16x8_sub_sat_u, binary_op_i16x8_mul, binary_op_i16x8_min_s,
		binary_op_i16x8_min_u, binary_op_i16x8_max_s, binary_op_i16x8_max_u,
		binary_op_i16x8_avgr_u, binary_op_i16x8_extmul_low_i8x16_s,
		binary_op_i16x8_extmul_high_i8x16_s, binary_op_i16x8_extmul_low_i8x16_u,
		binary_op_i16x8_extmul_high_i8x16_u, binary_op_i32x4_add, binary_op_i32x4_sub,
		binary_op_i32x4_mul, binary_op_i32x4_min_s, binary_op_i32x4_min_u, binary_op_i32x4_max_s,
		binary_op_i32x4_max_u, binary_op_i32x4_dot_i16x8_s, binary_op_i32x4_extmul_low_i16x8_s,
		binary_op_i32x4_extmul_high_i16x8_s, binary_op_i32x4_extmul_low_i16x8_u,
		binary_op_i32x4_extmul_high_i16x8_u, binary_op_i64x2_add, binary_op_i64x2_sub,
		binary_op_i64x2_mul, binary_op_i64x2_eq, binary_op_i64x2_ne, binary_op_i64x2_lt_s,
		binary_op_i64x2_gt_s, binary_op_i64x2_le_s, binary_op_i64x2_ge_s,
		binary_op_i64x2_extmul_low_i32x4_s, binary_op_i64x2_extmul_high_i32x4_s,
		binary_op_i64x2_extmul_low_i32x4_u, binary_op_i64x2_extmul_high_i32x4_u,
		binary_op_f32x4_add, binary_op_f32x4_sub, binary_op_f32x4_mul, binary_op_f32x4_div,
		binary_op_f32x4_min, binary_op_f32x4_max, binary_op_f32x4_pmin, binary_op_f32x4_pmax,
		binary_op_f64x2_add, binary_op_f64x2_sub, binary_op_f64x2_mul, binary_op_f64x2_div,
		binary_op_f64x2_min, binary_op_f64x2_max, binary_op_f64x2_pmin, binary_op_f64x2_pmax,
		binary_op_i8x16_relaxed_swizzle, binary_op_f32x4_relaxed_min, binary_op_f32x4_relaxed_max,
		binary_op_f64x2_relaxed_min, binary_op_f64x2_relaxed_max,
		binary_op_i16x8_relaxed_q15mulr_s, binary_op_i16x8_relaxed_dot_i8x16_i7x16_s {
			stack.take_and_put([BinaryValueKind.v128, .v128], .v128)!
			return false
		}
		binary_op_v128_not, binary_op_f32x4_demote_f64x2_zero, binary_op_f64x2_promote_low_f32x4,
		binary_op_i8x16_abs, binary_op_i8x16_neg, binary_op_i8x16_popcnt, binary_op_f32x4_ceil,
		binary_op_f32x4_floor, binary_op_f32x4_trunc, binary_op_f32x4_nearest,
		binary_op_f64x2_ceil, binary_op_f64x2_floor, binary_op_f64x2_trunc,
		binary_op_i16x8_extadd_pairwise_i8x16_s, binary_op_i16x8_extadd_pairwise_i8x16_u,
		binary_op_i32x4_extadd_pairwise_i16x8_s, binary_op_i32x4_extadd_pairwise_i16x8_u,
		binary_op_i16x8_abs, binary_op_i16x8_neg, binary_op_i16x8_extend_low_i8x16_s,
		binary_op_i16x8_extend_high_i8x16_s, binary_op_i16x8_extend_low_i8x16_u,
		binary_op_i16x8_extend_high_i8x16_u, binary_op_f64x2_nearest, binary_op_i32x4_abs,
		binary_op_i32x4_neg, binary_op_i32x4_extend_low_i16x8_s,
		binary_op_i32x4_extend_high_i16x8_s, binary_op_i32x4_extend_low_i16x8_u,
		binary_op_i32x4_extend_high_i16x8_u, binary_op_i64x2_abs, binary_op_i64x2_neg,
		binary_op_i64x2_extend_low_i32x4_s, binary_op_i64x2_extend_high_i32x4_s,
		binary_op_i64x2_extend_low_i32x4_u, binary_op_i64x2_extend_high_i32x4_u,
		binary_op_f32x4_abs, binary_op_f32x4_neg, binary_op_f32x4_sqrt, binary_op_f64x2_abs,
		binary_op_f64x2_neg, binary_op_f64x2_sqrt, binary_op_i32x4_trunc_sat_f32x4_s,
		binary_op_i32x4_trunc_sat_f32x4_u, binary_op_f32x4_convert_i32x4_s,
		binary_op_f32x4_convert_i32x4_u, binary_op_i32x4_trunc_sat_f64x2_s_zero,
		binary_op_i32x4_trunc_sat_f64x2_u_zero, binary_op_f64x2_convert_low_i32x4_s,
		binary_op_f64x2_convert_low_i32x4_u, binary_op_i32x4_relaxed_trunc_f32x4_s,
		binary_op_i32x4_relaxed_trunc_f32x4_u, binary_op_i32x4_relaxed_trunc_f64x2_s_zero,
		binary_op_i32x4_relaxed_trunc_f64x2_u_zero {
			stack.take_and_put([BinaryValueKind.v128], .v128)!
			return false
		}
		binary_op_v128_bitselect, binary_op_f32x4_relaxed_madd, binary_op_f32x4_relaxed_nmadd,
		binary_op_f64x2_relaxed_madd, binary_op_f64x2_relaxed_nmadd,
		binary_op_i8x16_relaxed_laneselect, binary_op_i16x8_relaxed_laneselect,
		binary_op_i32x4_relaxed_laneselect, binary_op_i64x2_relaxed_laneselect,
		binary_op_i32x4_relaxed_dot_i8x16_i7x16_add_s {
			stack.take_and_put([BinaryValueKind.v128, .v128, .v128], .v128)!
			return false
		}
		binary_op_v128_any_true, binary_op_i8x16_all_true, binary_op_i8x16_bitmask,
		binary_op_i16x8_all_true, binary_op_i16x8_bitmask, binary_op_i32x4_all_true,
		binary_op_i32x4_bitmask, binary_op_i64x2_all_true, binary_op_i64x2_bitmask {
			stack.take_and_put([BinaryValueKind.v128], .i32)!
			return false
		}
		binary_op_i8x16_shl, binary_op_i8x16_shr_s, binary_op_i8x16_shr_u, binary_op_i16x8_shl,
		binary_op_i16x8_shr_s, binary_op_i16x8_shr_u, binary_op_i32x4_shl, binary_op_i32x4_shr_s,
		binary_op_i32x4_shr_u, binary_op_i64x2_shl, binary_op_i64x2_shr_s, binary_op_i64x2_shr_u {
			stack.take_and_put([BinaryValueKind.i32, .v128], .v128)!
			return false
		}
		binary_op_synthetic_end_expression {
			return true
		}
		else { return error('instruction is outside the fixed-stack validation slice') }
	}
}
