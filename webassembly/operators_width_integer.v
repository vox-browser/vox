// Copyright (c) 2021-2023, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Operators.h Wrap, Extend and SignExtend scalar instruction specializations.
module webassembly

pub fn binary_wrap_i64_to_i32(lhs i64) i32 {
	return i32(u32(u64(lhs)))
}

pub fn binary_extend_i32_to_i64(lhs i32) i64 {
	return i64(lhs)
}

pub fn binary_extend_u32_to_i64(lhs u32) i64 {
	return i64(lhs)
}

pub fn binary_sign_extend_i8_to_i32(lhs i32) i32 {
	unsigned_representation := u32(lhs)
	truncated_unsigned_representation := u8(unsigned_representation)
	initial_value := i8(truncated_unsigned_representation)
	return i32(initial_value)
}

pub fn binary_sign_extend_i16_to_i32(lhs i32) i32 {
	unsigned_representation := u32(lhs)
	truncated_unsigned_representation := u16(unsigned_representation)
	initial_value := i16(truncated_unsigned_representation)
	return i32(initial_value)
}

pub fn binary_sign_extend_i8_to_i64(lhs i64) i64 {
	unsigned_representation := u64(lhs)
	truncated_unsigned_representation := u8(unsigned_representation)
	initial_value := i8(truncated_unsigned_representation)
	return i64(initial_value)
}

pub fn binary_sign_extend_i16_to_i64(lhs i64) i64 {
	unsigned_representation := u64(lhs)
	truncated_unsigned_representation := u16(unsigned_representation)
	initial_value := i16(truncated_unsigned_representation)
	return i64(initial_value)
}

pub fn binary_sign_extend_i32_to_i64(lhs i64) i64 {
	unsigned_representation := u64(lhs)
	truncated_unsigned_representation := u32(unsigned_representation)
	initial_value := i32(truncated_unsigned_representation)
	return i64(initial_value)
}
