// Copyright (c) 2021-2023, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Operators.h DEFINE_BINARY_OPERATOR comparisons with the float/double
// PopType specializations in BytecodeInterpreter.cpp.
module webassembly

pub fn binary_equals_f32(lhs f32, rhs f32) bool { return lhs == rhs }

pub fn binary_equals_f64(lhs f64, rhs f64) bool { return lhs == rhs }

pub fn binary_not_equals_f32(lhs f32, rhs f32) bool { return lhs != rhs }

pub fn binary_not_equals_f64(lhs f64, rhs f64) bool { return lhs != rhs }

pub fn binary_less_than_f32(lhs f32, rhs f32) bool { return lhs < rhs }

pub fn binary_less_than_f64(lhs f64, rhs f64) bool { return lhs < rhs }

pub fn binary_greater_than_f32(lhs f32, rhs f32) bool { return lhs > rhs }

pub fn binary_greater_than_f64(lhs f64, rhs f64) bool { return lhs > rhs }

pub fn binary_less_than_or_equals_f32(lhs f32, rhs f32) bool { return lhs <= rhs }

pub fn binary_less_than_or_equals_f64(lhs f64, rhs f64) bool { return lhs <= rhs }

pub fn binary_greater_than_or_equals_f32(lhs f32, rhs f32) bool { return lhs >= rhs }

pub fn binary_greater_than_or_equals_f64(lhs f64, rhs f64) bool { return lhs >= rhs }
