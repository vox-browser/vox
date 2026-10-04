// Copyright (c) 2021-2023, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Operators.h DEFINE_BINARY_OPERATOR comparison records. Concrete PopType
// specializations follow the integer handlers in BytecodeInterpreter.cpp.
module webassembly

pub fn binary_equals_i32(lhs i32, rhs i32) bool { return lhs == rhs }

pub fn binary_equals_i64(lhs i64, rhs i64) bool { return lhs == rhs }

pub fn binary_not_equals_i32(lhs i32, rhs i32) bool { return lhs != rhs }

pub fn binary_not_equals_i64(lhs i64, rhs i64) bool { return lhs != rhs }

pub fn binary_less_than_i32(lhs i32, rhs i32) bool { return lhs < rhs }

pub fn binary_less_than_u32(lhs u32, rhs u32) bool { return lhs < rhs }

pub fn binary_less_than_i64(lhs i64, rhs i64) bool { return lhs < rhs }

pub fn binary_less_than_u64(lhs u64, rhs u64) bool { return lhs < rhs }

pub fn binary_greater_than_i32(lhs i32, rhs i32) bool { return lhs > rhs }

pub fn binary_greater_than_u32(lhs u32, rhs u32) bool { return lhs > rhs }

pub fn binary_greater_than_i64(lhs i64, rhs i64) bool { return lhs > rhs }

pub fn binary_greater_than_u64(lhs u64, rhs u64) bool { return lhs > rhs }

pub fn binary_less_than_or_equals_i32(lhs i32, rhs i32) bool { return lhs <= rhs }

pub fn binary_less_than_or_equals_u32(lhs u32, rhs u32) bool { return lhs <= rhs }

pub fn binary_less_than_or_equals_i64(lhs i64, rhs i64) bool { return lhs <= rhs }

pub fn binary_less_than_or_equals_u64(lhs u64, rhs u64) bool { return lhs <= rhs }

pub fn binary_greater_than_or_equals_i32(lhs i32, rhs i32) bool { return lhs >= rhs }

pub fn binary_greater_than_or_equals_u32(lhs u32, rhs u32) bool { return lhs >= rhs }

pub fn binary_greater_than_or_equals_i64(lhs i64, rhs i64) bool { return lhs >= rhs }

pub fn binary_greater_than_or_equals_u64(lhs u64, rhs u64) bool { return lhs >= rhs }
