// Copyright (c) 2021-2023, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Operators.h DEFINE_BINARY_OPERATOR arithmetic and bitwise records.
// BytecodeInterpreter uses unsigned arithmetic PopType and signed bitwise PopType.
module webassembly

pub fn binary_add_u32(lhs u32, rhs u32) u32 { return lhs + rhs }

pub fn binary_add_u64(lhs u64, rhs u64) u64 { return lhs + rhs }

pub fn binary_subtract_u32(lhs u32, rhs u32) u32 { return lhs - rhs }

pub fn binary_subtract_u64(lhs u64, rhs u64) u64 { return lhs - rhs }

pub fn binary_multiply_u32(lhs u32, rhs u32) u32 { return lhs * rhs }

pub fn binary_multiply_u64(lhs u64, rhs u64) u64 { return lhs * rhs }

pub fn binary_bit_and_i32(lhs i32, rhs i32) i32 { return lhs & rhs }

pub fn binary_bit_and_i64(lhs i64, rhs i64) i64 { return lhs & rhs }

pub fn binary_bit_or_i32(lhs i32, rhs i32) i32 { return lhs | rhs }

pub fn binary_bit_or_i64(lhs i64, rhs i64) i64 { return lhs | rhs }

pub fn binary_bit_xor_i32(lhs i32, rhs i32) i32 { return lhs ^ rhs }

pub fn binary_bit_xor_i64(lhs i64, rhs i64) i64 { return lhs ^ rhs }
