// Copyright (c) 2021-2023, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Operators.h Add/Subtract/Multiply macros and Divide's floating branch.
// BytecodeInterpreter.cpp uses the same float/double PopType and PushType.
module webassembly

pub fn binary_add_f32(lhs f32, rhs f32) f32 { return lhs + rhs }

pub fn binary_add_f64(lhs f64, rhs f64) f64 { return lhs + rhs }

pub fn binary_subtract_f32(lhs f32, rhs f32) f32 { return lhs - rhs }

pub fn binary_subtract_f64(lhs f64, rhs f64) f64 { return lhs - rhs }

pub fn binary_multiply_f32(lhs f32, rhs f32) f32 { return lhs * rhs }

pub fn binary_multiply_f64(lhs f64, rhs f64) f64 { return lhs * rhs }

pub fn binary_divide_f32(lhs f32, rhs f32) f32 { return lhs / rhs }

pub fn binary_divide_f64(lhs f64, rhs f64) f64 { return lhs / rhs }
