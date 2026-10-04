// Copyright (c) 2021-2023, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Operators.h Reinterpret: four scalar equal-width bit_cast specializations.
module webassembly

import math

pub fn binary_reinterpret_f32_to_i32(lhs f32) i32 {
	return i32(math.f32_bits(lhs))
}

pub fn binary_reinterpret_f64_to_i64(lhs f64) i64 {
	return i64(math.f64_bits(lhs))
}

pub fn binary_reinterpret_i32_to_f32(lhs i32) f32 {
	return math.f32_from_bits(u32(lhs))
}

pub fn binary_reinterpret_i64_to_f64(lhs i64) f64 {
	return math.f64_from_bits(u64(lhs))
}
