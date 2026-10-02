// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Pinned source instruction dispatch: Ladybird 963d46a829f3e1b79f44dba9d02afb70654300fa.
// Regenerate with tools/generate_wasm_validation_dispatch.py.
module webassembly

pub fn (mut validator BinaryInstructionValidator) validate_instruction(mut instruction BinaryInstruction, mut stack BinaryValidationStack) !bool {
	match instruction.opcode {
		binary_op_f32_abs, binary_op_f32_add, binary_op_f32_ceil, binary_op_f32_const,
		binary_op_f32_convert_si32, binary_op_f32_convert_si64, binary_op_f32_convert_ui32,
		binary_op_f32_convert_ui64, binary_op_f32_copysign, binary_op_f32_demote_f64,
		binary_op_f32_div, binary_op_f32_eq, binary_op_f32_floor, binary_op_f32_ge,
		binary_op_f32_gt, binary_op_f32_le, binary_op_f32_lt, binary_op_f32_max, binary_op_f32_min,
		binary_op_f32_mul, binary_op_f32_ne, binary_op_f32_nearest, binary_op_f32_neg,
		binary_op_f32_reinterpret_i32, binary_op_f32_sqrt, binary_op_f32_sub, binary_op_f32_trunc,
		binary_op_f32x4_abs, binary_op_f32x4_add, binary_op_f32x4_ceil,
		binary_op_f32x4_convert_i32x4_s, binary_op_f32x4_convert_i32x4_u,
		binary_op_f32x4_demote_f64x2_zero, binary_op_f32x4_div, binary_op_f32x4_eq,
		binary_op_f32x4_floor, binary_op_f32x4_ge, binary_op_f32x4_gt, binary_op_f32x4_le,
		binary_op_f32x4_lt, binary_op_f32x4_max, binary_op_f32x4_min, binary_op_f32x4_mul,
		binary_op_f32x4_ne, binary_op_f32x4_nearest, binary_op_f32x4_neg, binary_op_f32x4_pmax,
		binary_op_f32x4_pmin, binary_op_f32x4_relaxed_madd, binary_op_f32x4_relaxed_max,
		binary_op_f32x4_relaxed_min, binary_op_f32x4_relaxed_nmadd, binary_op_f32x4_sqrt,
		binary_op_f32x4_sub, binary_op_f32x4_trunc, binary_op_f64_abs, binary_op_f64_add,
		binary_op_f64_ceil, binary_op_f64_const, binary_op_f64_convert_si32,
		binary_op_f64_convert_si64, binary_op_f64_convert_ui32, binary_op_f64_convert_ui64,
		binary_op_f64_copysign, binary_op_f64_div, binary_op_f64_eq, binary_op_f64_floor,
		binary_op_f64_ge, binary_op_f64_gt, binary_op_f64_le, binary_op_f64_lt, binary_op_f64_max,
		binary_op_f64_min, binary_op_f64_mul, binary_op_f64_ne, binary_op_f64_nearest,
		binary_op_f64_neg, binary_op_f64_promote_f32, binary_op_f64_reinterpret_i64,
		binary_op_f64_sqrt, binary_op_f64_sub, binary_op_f64_trunc, binary_op_f64x2_abs,
		binary_op_f64x2_add, binary_op_f64x2_ceil, binary_op_f64x2_convert_low_i32x4_s,
		binary_op_f64x2_convert_low_i32x4_u, binary_op_f64x2_div, binary_op_f64x2_eq,
		binary_op_f64x2_floor, binary_op_f64x2_ge, binary_op_f64x2_gt, binary_op_f64x2_le,
		binary_op_f64x2_lt, binary_op_f64x2_max, binary_op_f64x2_min, binary_op_f64x2_mul,
		binary_op_f64x2_ne, binary_op_f64x2_nearest, binary_op_f64x2_neg, binary_op_f64x2_pmax,
		binary_op_f64x2_pmin, binary_op_f64x2_promote_low_f32x4, binary_op_f64x2_relaxed_madd,
		binary_op_f64x2_relaxed_max, binary_op_f64x2_relaxed_min, binary_op_f64x2_relaxed_nmadd,
		binary_op_f64x2_sqrt, binary_op_f64x2_sub, binary_op_f64x2_trunc, binary_op_i16x8_abs,
		binary_op_i16x8_add, binary_op_i16x8_add_sat_s, binary_op_i16x8_add_sat_u,
		binary_op_i16x8_all_true, binary_op_i16x8_avgr_u, binary_op_i16x8_bitmask,
		binary_op_i16x8_eq, binary_op_i16x8_extadd_pairwise_i8x16_s,
		binary_op_i16x8_extadd_pairwise_i8x16_u, binary_op_i16x8_extend_high_i8x16_s,
		binary_op_i16x8_extend_high_i8x16_u, binary_op_i16x8_extend_low_i8x16_s,
		binary_op_i16x8_extend_low_i8x16_u, binary_op_i16x8_extmul_high_i8x16_s,
		binary_op_i16x8_extmul_high_i8x16_u, binary_op_i16x8_extmul_low_i8x16_s,
		binary_op_i16x8_extmul_low_i8x16_u, binary_op_i16x8_ge_s, binary_op_i16x8_ge_u,
		binary_op_i16x8_gt_s, binary_op_i16x8_gt_u, binary_op_i16x8_le_s, binary_op_i16x8_le_u,
		binary_op_i16x8_lt_s, binary_op_i16x8_lt_u, binary_op_i16x8_max_s, binary_op_i16x8_max_u,
		binary_op_i16x8_min_s, binary_op_i16x8_min_u, binary_op_i16x8_mul,
		binary_op_i16x8_narrow_i32x4_s, binary_op_i16x8_narrow_i32x4_u, binary_op_i16x8_ne,
		binary_op_i16x8_neg, binary_op_i16x8_q15mulr_sat_s,
		binary_op_i16x8_relaxed_dot_i8x16_i7x16_s, binary_op_i16x8_relaxed_laneselect,
		binary_op_i16x8_relaxed_q15mulr_s, binary_op_i16x8_shl, binary_op_i16x8_shr_s,
		binary_op_i16x8_shr_u, binary_op_i16x8_sub, binary_op_i16x8_sub_sat_s,
		binary_op_i16x8_sub_sat_u, binary_op_i32_add, binary_op_i32_and, binary_op_i32_clz,
		binary_op_i32_const, binary_op_i32_ctz, binary_op_i32_divs, binary_op_i32_divu,
		binary_op_i32_eq, binary_op_i32_eqz, binary_op_i32_extend16_s, binary_op_i32_extend8_s,
		binary_op_i32_ges, binary_op_i32_geu, binary_op_i32_gts, binary_op_i32_gtu,
		binary_op_i32_les, binary_op_i32_leu, binary_op_i32_lts, binary_op_i32_ltu,
		binary_op_i32_mul, binary_op_i32_ne, binary_op_i32_or, binary_op_i32_popcnt,
		binary_op_i32_reinterpret_f32, binary_op_i32_rems, binary_op_i32_remu, binary_op_i32_rotl,
		binary_op_i32_rotr, binary_op_i32_shl, binary_op_i32_shrs, binary_op_i32_shru,
		binary_op_i32_sub, binary_op_i32_trunc_sat_f32_s, binary_op_i32_trunc_sat_f32_u,
		binary_op_i32_trunc_sat_f64_s, binary_op_i32_trunc_sat_f64_u, binary_op_i32_trunc_sf32,
		binary_op_i32_trunc_sf64, binary_op_i32_trunc_uf32, binary_op_i32_trunc_uf64,
		binary_op_i32_wrap_i64, binary_op_i32_xor, binary_op_i32x4_abs, binary_op_i32x4_add,
		binary_op_i32x4_all_true, binary_op_i32x4_bitmask, binary_op_i32x4_dot_i16x8_s,
		binary_op_i32x4_eq, binary_op_i32x4_extadd_pairwise_i16x8_s,
		binary_op_i32x4_extadd_pairwise_i16x8_u, binary_op_i32x4_extend_high_i16x8_s,
		binary_op_i32x4_extend_high_i16x8_u, binary_op_i32x4_extend_low_i16x8_s,
		binary_op_i32x4_extend_low_i16x8_u, binary_op_i32x4_extmul_high_i16x8_s,
		binary_op_i32x4_extmul_high_i16x8_u, binary_op_i32x4_extmul_low_i16x8_s,
		binary_op_i32x4_extmul_low_i16x8_u, binary_op_i32x4_ge_s, binary_op_i32x4_ge_u,
		binary_op_i32x4_gt_s, binary_op_i32x4_gt_u, binary_op_i32x4_le_s, binary_op_i32x4_le_u,
		binary_op_i32x4_lt_s, binary_op_i32x4_lt_u, binary_op_i32x4_max_s, binary_op_i32x4_max_u,
		binary_op_i32x4_min_s, binary_op_i32x4_min_u, binary_op_i32x4_mul, binary_op_i32x4_ne,
		binary_op_i32x4_neg, binary_op_i32x4_relaxed_dot_i8x16_i7x16_add_s,
		binary_op_i32x4_relaxed_laneselect, binary_op_i32x4_relaxed_trunc_f32x4_s,
		binary_op_i32x4_relaxed_trunc_f32x4_u, binary_op_i32x4_relaxed_trunc_f64x2_s_zero,
		binary_op_i32x4_relaxed_trunc_f64x2_u_zero, binary_op_i32x4_shl, binary_op_i32x4_shr_s,
		binary_op_i32x4_shr_u, binary_op_i32x4_sub, binary_op_i32x4_trunc_sat_f32x4_s,
		binary_op_i32x4_trunc_sat_f32x4_u, binary_op_i32x4_trunc_sat_f64x2_s_zero,
		binary_op_i32x4_trunc_sat_f64x2_u_zero, binary_op_i64_add, binary_op_i64_and,
		binary_op_i64_clz, binary_op_i64_const, binary_op_i64_ctz, binary_op_i64_divs,
		binary_op_i64_divu, binary_op_i64_eq, binary_op_i64_eqz, binary_op_i64_extend16_s,
		binary_op_i64_extend32_s, binary_op_i64_extend8_s, binary_op_i64_extend_si32,
		binary_op_i64_extend_ui32, binary_op_i64_ges, binary_op_i64_geu, binary_op_i64_gts,
		binary_op_i64_gtu, binary_op_i64_les, binary_op_i64_leu, binary_op_i64_lts,
		binary_op_i64_ltu, binary_op_i64_mul, binary_op_i64_ne, binary_op_i64_or,
		binary_op_i64_popcnt, binary_op_i64_reinterpret_f64, binary_op_i64_rems,
		binary_op_i64_remu, binary_op_i64_rotl, binary_op_i64_rotr, binary_op_i64_shl,
		binary_op_i64_shrs, binary_op_i64_shru, binary_op_i64_sub, binary_op_i64_trunc_sat_f32_s,
		binary_op_i64_trunc_sat_f32_u, binary_op_i64_trunc_sat_f64_s,
		binary_op_i64_trunc_sat_f64_u, binary_op_i64_trunc_sf32, binary_op_i64_trunc_sf64,
		binary_op_i64_trunc_uf32, binary_op_i64_trunc_uf64, binary_op_i64_xor, binary_op_i64x2_abs,
		binary_op_i64x2_add, binary_op_i64x2_all_true, binary_op_i64x2_bitmask, binary_op_i64x2_eq,
		binary_op_i64x2_extend_high_i32x4_s, binary_op_i64x2_extend_high_i32x4_u,
		binary_op_i64x2_extend_low_i32x4_s, binary_op_i64x2_extend_low_i32x4_u,
		binary_op_i64x2_extmul_high_i32x4_s, binary_op_i64x2_extmul_high_i32x4_u,
		binary_op_i64x2_extmul_low_i32x4_s, binary_op_i64x2_extmul_low_i32x4_u,
		binary_op_i64x2_ge_s, binary_op_i64x2_gt_s, binary_op_i64x2_le_s, binary_op_i64x2_lt_s,
		binary_op_i64x2_mul, binary_op_i64x2_ne, binary_op_i64x2_neg,
		binary_op_i64x2_relaxed_laneselect, binary_op_i64x2_shl, binary_op_i64x2_shr_s,
		binary_op_i64x2_shr_u, binary_op_i64x2_sub, binary_op_i8x16_abs, binary_op_i8x16_add,
		binary_op_i8x16_add_sat_s, binary_op_i8x16_add_sat_u, binary_op_i8x16_all_true,
		binary_op_i8x16_avgr_u, binary_op_i8x16_bitmask, binary_op_i8x16_eq, binary_op_i8x16_ge_s,
		binary_op_i8x16_ge_u, binary_op_i8x16_gt_s, binary_op_i8x16_gt_u, binary_op_i8x16_le_s,
		binary_op_i8x16_le_u, binary_op_i8x16_lt_s, binary_op_i8x16_lt_u, binary_op_i8x16_max_s,
		binary_op_i8x16_max_u, binary_op_i8x16_min_s, binary_op_i8x16_min_u,
		binary_op_i8x16_narrow_i16x8_s, binary_op_i8x16_narrow_i16x8_u, binary_op_i8x16_ne,
		binary_op_i8x16_neg, binary_op_i8x16_popcnt, binary_op_i8x16_relaxed_laneselect,
		binary_op_i8x16_relaxed_swizzle, binary_op_i8x16_shl, binary_op_i8x16_shr_s,
		binary_op_i8x16_shr_u, binary_op_i8x16_sub, binary_op_i8x16_sub_sat_s,
		binary_op_i8x16_sub_sat_u, binary_op_i8x16_swizzle, binary_op_nop,
		binary_op_synthetic_end_expression, binary_op_v128_and, binary_op_v128_andnot,
		binary_op_v128_any_true, binary_op_v128_bitselect, binary_op_v128_const,
		binary_op_v128_not, binary_op_v128_or, binary_op_v128_xor {
			return validate_binary_fixed_stack_instruction(instruction, mut stack)
		}
		binary_op_drop, binary_op_global_get, binary_op_global_set, binary_op_local_get,
		binary_op_local_set, binary_op_local_tee, binary_op_ref_func, binary_op_ref_is_null,
		binary_op_ref_null, binary_op_select, binary_op_select_typed {
			return validate_binary_reference_variable_instruction(instruction, mut validator, mut stack)
		}
		binary_op_block, binary_op_br, binary_op_br_if, binary_op_br_table, binary_op_if_,
		binary_op_loop, binary_op_return_, binary_op_structured_else, binary_op_structured_end,
		binary_op_throw_, binary_op_throw_ref, binary_op_try_table, binary_op_unreachable {
			return validate_binary_control_instruction(mut instruction, mut validator, mut stack)
		}
		binary_op_call, binary_op_call_indirect, binary_op_call_ref, binary_op_return_call,
		binary_op_return_call_indirect, binary_op_return_call_ref {
			return validate_binary_call_instruction(instruction, mut validator, mut stack)
		}
		binary_op_elem_drop, binary_op_table_copy, binary_op_table_fill, binary_op_table_get,
		binary_op_table_grow, binary_op_table_init, binary_op_table_set, binary_op_table_size {
			return validate_binary_table_instruction(instruction, &validator, mut stack)
		}
		binary_op_f32_load, binary_op_f32_store, binary_op_f64_load, binary_op_f64_store,
		binary_op_i32_load, binary_op_i32_load16_s, binary_op_i32_load16_u, binary_op_i32_load8_s,
		binary_op_i32_load8_u, binary_op_i32_store, binary_op_i32_store16, binary_op_i32_store8,
		binary_op_i64_load, binary_op_i64_load16_s, binary_op_i64_load16_u, binary_op_i64_load32_s,
		binary_op_i64_load32_u, binary_op_i64_load8_s, binary_op_i64_load8_u, binary_op_i64_store,
		binary_op_i64_store16, binary_op_i64_store32, binary_op_i64_store8, binary_op_v128_load {
			return validate_binary_memory_access_instruction(instruction, &validator, mut stack)
		}
		binary_op_data_drop, binary_op_memory_copy, binary_op_memory_fill, binary_op_memory_grow,
		binary_op_memory_init, binary_op_memory_size {
			return validate_binary_memory_bulk_instruction(instruction, &validator, mut stack)
		}
		binary_op_f32x4_extract_lane, binary_op_f32x4_replace_lane, binary_op_f32x4_splat,
		binary_op_f64x2_extract_lane, binary_op_f64x2_replace_lane, binary_op_f64x2_splat,
		binary_op_i16x8_extract_lane_s, binary_op_i16x8_extract_lane_u,
		binary_op_i16x8_replace_lane, binary_op_i16x8_splat, binary_op_i32x4_extract_lane,
		binary_op_i32x4_replace_lane, binary_op_i32x4_splat, binary_op_i64x2_extract_lane,
		binary_op_i64x2_replace_lane, binary_op_i64x2_splat, binary_op_i8x16_extract_lane_s,
		binary_op_i8x16_extract_lane_u, binary_op_i8x16_replace_lane, binary_op_i8x16_shuffle,
		binary_op_i8x16_splat {
			return validate_binary_simd_lane_instruction(instruction, mut stack)
		}
		binary_op_v128_load16_lane, binary_op_v128_load16_splat, binary_op_v128_load16x4_s,
		binary_op_v128_load16x4_u, binary_op_v128_load32_lane, binary_op_v128_load32_splat,
		binary_op_v128_load32_zero, binary_op_v128_load32x2_s, binary_op_v128_load32x2_u,
		binary_op_v128_load64_lane, binary_op_v128_load64_splat, binary_op_v128_load64_zero,
		binary_op_v128_load8_lane, binary_op_v128_load8_splat, binary_op_v128_load8x8_s,
		binary_op_v128_load8x8_u, binary_op_v128_store, binary_op_v128_store16_lane,
		binary_op_v128_store32_lane, binary_op_v128_store64_lane, binary_op_v128_store8_lane {
			return validate_binary_simd_memory_instruction(instruction, &validator, mut stack)
		}
		binary_op_any_convert_extern, binary_op_br_on_cast, binary_op_br_on_cast_fail,
		binary_op_br_on_non_null, binary_op_br_on_null, binary_op_extern_convert_any,
		binary_op_i31_get_s, binary_op_i31_get_u, binary_op_ref_as_non_null, binary_op_ref_cast,
		binary_op_ref_cast_null, binary_op_ref_eq, binary_op_ref_i31, binary_op_ref_test,
		binary_op_ref_test_null {
			return validate_binary_gc_reference_instruction(mut instruction, &validator, mut stack)
		}
		binary_op_array_copy, binary_op_array_fill, binary_op_array_get, binary_op_array_get_s,
		binary_op_array_get_u, binary_op_array_init_data, binary_op_array_init_elem,
		binary_op_array_len, binary_op_array_new, binary_op_array_new_data,
		binary_op_array_new_default, binary_op_array_new_elem, binary_op_array_new_fixed,
		binary_op_array_set, binary_op_struct_get, binary_op_struct_get_s, binary_op_struct_get_u,
		binary_op_struct_new, binary_op_struct_new_default, binary_op_struct_set {
			return validate_binary_gc_aggregate_instruction(instruction, &validator, mut stack)
		}
		else {
			return error('CompileError: invalid instruction opcode (0x${instruction.opcode:x})')
		}
	}
}
