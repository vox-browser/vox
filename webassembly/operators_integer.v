// Copyright (c) 2021-2023, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// AbstractMachine/Operators.h: Divide, Modulo, BitRotateLeft and BitRotateRight.
// Concrete scalar specializations replace the source's operator templates.
module webassembly

pub fn binary_divide_i32(lhs i32, rhs i32) !i32 {
	// AK/Checked.h::div checks signed overflow before the zero-divisor gate.
	if rhs == -1 && lhs == i32(-2147483648) { return error('Integer division overflow') }
	if rhs == 0 { return error('Integer division overflow') }
	return lhs / rhs
}

pub fn binary_divide_u32(lhs u32, rhs u32) !u32 {
	if rhs == 0 { return error('Integer division overflow') }
	return lhs / rhs
}

pub fn binary_divide_i64(lhs i64, rhs i64) !i64 {
	if rhs == -1 && lhs == i64(-9223372036854775807) - 1 {
		return error('Integer division overflow')
	}
	if rhs == 0 { return error('Integer division overflow') }
	return lhs / rhs
}

pub fn binary_divide_u64(lhs u64, rhs u64) !u64 {
	if rhs == 0 { return error('Integer division overflow') }
	return lhs / rhs
}

pub fn binary_modulo_i32(lhs i32, rhs i32) !i32 {
	if rhs == 0 { return error('Integer division overflow') }
	if rhs == -1 { return 0 }
	return lhs % rhs
}

pub fn binary_modulo_u32(lhs u32, rhs u32) !u32 {
	if rhs == 0 { return error('Integer division overflow') }
	return lhs % rhs
}

pub fn binary_modulo_i64(lhs i64, rhs i64) !i64 {
	if rhs == 0 { return error('Integer division overflow') }
	if rhs == -1 { return 0 }
	return lhs % rhs
}

pub fn binary_modulo_u64(lhs u64, rhs u64) !u64 {
	if rhs == 0 { return error('Integer division overflow') }
	return lhs % rhs
}

pub fn binary_rotate_left_u32(lhs u32, rhs u32) u32 {
	shift := rhs & 31
	return (lhs << shift) | (lhs >> ((u32(0) - shift) & 31))
}

pub fn binary_rotate_right_u32(lhs u32, rhs u32) u32 {
	shift := rhs & 31
	return (lhs >> shift) | (lhs << ((u32(0) - shift) & 31))
}

pub fn binary_rotate_left_u64(lhs u64, rhs u64) u64 {
	shift := rhs & 63
	return (lhs << shift) | (lhs >> ((u64(0) - shift) & 63))
}

pub fn binary_rotate_right_u64(lhs u64, rhs u64) u64 {
	shift := rhs & 63
	return (lhs >> shift) | (lhs << ((u64(0) - shift) & 63))
}
