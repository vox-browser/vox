// Copyright (c) 2021-2023, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Operators.h's seven float/double unary specializations.
module webassembly

import math

#include "@DIR/operators_unary_float_host.h"

fn C.vox_wasm_isnan_f32(f32) int
fn C.vox_wasm_isnan_f64(f64) int
fn C.vox_wasm_abs_f32(f32) f32
fn C.vox_wasm_abs_f64(f64) f64
fn C.ceilf(f32) f32
fn C.ceil(f64) f64
fn C.floorf(f32) f32
fn C.floor(f64) f64
fn C.truncf(f32) f32
fn C.trunc(f64) f64
fn C.nearbyintf(f32) f32
fn C.nearbyint(f64) f64
fn C.sqrtf(f32) f32
fn C.sqrt(f64) f64

pub fn binary_absolute_f32(lhs f32) f32 { return C.vox_wasm_abs_f32(lhs) }

pub fn binary_absolute_f64(lhs f64) f64 { return C.vox_wasm_abs_f64(lhs) }

pub fn binary_negate_f32(lhs f32) f32 { return -lhs }

pub fn binary_negate_f64(lhs f64) f64 { return -lhs }

pub fn binary_ceil_f32(lhs f32) f32 {
	if C.vox_wasm_isnan_f32(lhs) != 0 { return math.f32_from_bits(0x7fc00000) }
	return C.ceilf(lhs)
}

pub fn binary_ceil_f64(lhs f64) f64 {
	if C.vox_wasm_isnan_f64(lhs) != 0 { return math.f64_from_bits(0x7ff8000000000000) }
	return C.ceil(lhs)
}

pub fn binary_floor_f32(lhs f32) f32 {
	if C.vox_wasm_isnan_f32(lhs) != 0 { return math.f32_from_bits(0x7fc00000) }
	return C.floorf(lhs)
}

pub fn binary_floor_f64(lhs f64) f64 {
	if C.vox_wasm_isnan_f64(lhs) != 0 { return math.f64_from_bits(0x7ff8000000000000) }
	return C.floor(lhs)
}

pub fn binary_truncate_f32(lhs f32) f32 {
	if C.vox_wasm_isnan_f32(lhs) != 0 { return math.f32_from_bits(0x7fc00000) }
	return C.truncf(lhs)
}

pub fn binary_truncate_f64(lhs f64) f64 {
	if C.vox_wasm_isnan_f64(lhs) != 0 { return math.f64_from_bits(0x7ff8000000000000) }
	return C.trunc(lhs)
}

pub fn binary_nearby_integral_f32(lhs f32) f32 { return C.nearbyintf(lhs) }

pub fn binary_nearby_integral_f64(lhs f64) f64 { return C.nearbyint(lhs) }

pub fn binary_square_root_f32(lhs f32) f32 { return C.sqrtf(lhs) }

pub fn binary_square_root_f64(lhs f64) f64 { return C.sqrt(lhs) }
