// Copyright (c) 2021-2023, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Operators.h Minimum, Maximum and CopySign floating specializations.
module webassembly

import math

#include <math.h>

fn C.copysignf(f32, f32) f32
fn C.copysign(f64, f64) f64

pub fn binary_minimum_f32(lhs f32, rhs f32) f32 {
	if math.is_nan(lhs) || math.is_nan(rhs) {
		// AK::NaN<float> is __builtin_nan("") converted to float.
		return math.f32_from_bits(0x7fc00000)
	}
	if lhs == 0 && rhs == 0 {
		if math.signbit(lhs) { return lhs }
		return rhs
	}
	// AK::min returns b < a ? b : a.
	if rhs < lhs { return rhs }
	return lhs
}

pub fn binary_minimum_f64(lhs f64, rhs f64) f64 {
	if math.is_nan(lhs) || math.is_nan(rhs) {
		return math.f64_from_bits(0x7ff8000000000000)
	}
	if lhs == 0 && rhs == 0 {
		if math.signbit(lhs) { return lhs }
		return rhs
	}
	if rhs < lhs { return rhs }
	return lhs
}

pub fn binary_maximum_f32(lhs f32, rhs f32) f32 {
	if math.is_nan(lhs) || math.is_nan(rhs) {
		return math.f32_from_bits(0x7fc00000)
	}
	if lhs == 0 && rhs == 0 {
		if math.signbit(lhs) { return rhs }
		return lhs
	}
	// AK::max returns a < b ? b : a.
	if lhs < rhs { return rhs }
	return lhs
}

pub fn binary_maximum_f64(lhs f64, rhs f64) f64 {
	if math.is_nan(lhs) || math.is_nan(rhs) {
		return math.f64_from_bits(0x7ff8000000000000)
	}
	if lhs == 0 && rhs == 0 {
		if math.signbit(lhs) { return rhs }
		return lhs
	}
	if lhs < rhs { return rhs }
	return lhs
}

pub fn binary_copy_sign_f32(lhs f32, rhs f32) f32 { return C.copysignf(lhs, rhs) }

pub fn binary_copy_sign_f64(lhs f64, rhs f64) f64 { return C.copysign(lhs, rhs) }
