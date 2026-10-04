// Copyright (c) 2021-2023, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Operators.h: BitShiftLeft and BitShiftRight. Concrete scalar specializations
// use the exact PopType choices in BytecodeInterpreter's integer handlers.
module webassembly

pub fn binary_shift_left_u32(lhs u32, rhs u32) u32 {
	return lhs << (rhs % 32)
}

pub fn binary_shift_left_u64(lhs u64, rhs u64) u64 {
	return lhs << (rhs % 64)
}

pub fn binary_shift_right_i32(lhs i32, rhs i32) i32 {
	// Source sizeof(lhs) * 8 is unsigned size_t, converting even negative RHS
	// to that unsigned type before %. Preserve that promotion in V.
	return lhs >> (u64(rhs) % 32)
}

pub fn binary_shift_right_u32(lhs u32, rhs u32) u32 {
	return lhs >> (rhs % 32)
}

pub fn binary_shift_right_i64(lhs i64, rhs i64) i64 {
	return lhs >> (u64(rhs) % 64)
}

pub fn binary_shift_right_u64(lhs u64, rhs u64) u64 {
	return lhs >> (rhs % 64)
}
