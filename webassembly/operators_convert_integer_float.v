// Copyright (c) 2021-2023, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Operators.h Convert: identity bit_cast of interpreted input, then static_cast.
module webassembly

pub fn binary_convert_i32_to_f32(lhs i32) f32 { return f32(lhs) }

pub fn binary_convert_u32_to_f32(lhs u32) f32 { return f32(lhs) }

pub fn binary_convert_i64_to_f32(lhs i64) f32 { return f32(lhs) }

pub fn binary_convert_u64_to_f32(lhs u64) f32 { return f32(lhs) }

pub fn binary_convert_i32_to_f64(lhs i32) f64 { return f64(lhs) }

pub fn binary_convert_u32_to_f64(lhs u32) f64 { return f64(lhs) }

pub fn binary_convert_i64_to_f64(lhs i64) f64 { return f64(lhs) }

pub fn binary_convert_u64_to_f64(lhs u64) f64 { return f64(lhs) }
