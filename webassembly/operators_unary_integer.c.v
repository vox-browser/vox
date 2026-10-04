// Copyright (c) 2021-2023, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Operators.h: EqualsZero, CountLeadingZeros, CountTrailingZeros, PopCount.
module webassembly

#include "@DIR/operators_unary_integer_host.h"

fn C.vox_wasm_clz32(u32) i32
fn C.vox_wasm_clz64(u64) i32
fn C.vox_wasm_ctz32(u32) i32
fn C.vox_wasm_ctz64(u64) i32
fn C.vox_wasm_popcount8(u8) i32
fn C.vox_wasm_popcount16(u16) i32
fn C.vox_wasm_popcount32(u32) i32
fn C.vox_wasm_popcount64(u64) i32

pub fn binary_equals_zero_i32(lhs i32) bool { return lhs == 0 }

pub fn binary_equals_zero_i64(lhs i64) bool { return lhs == 0 }

pub fn binary_count_leading_zeros_i32(lhs i32) i32 {
	if lhs == 0 { return 32 }
	return C.vox_wasm_clz32(u32(lhs))
}

pub fn binary_count_leading_zeros_i64(lhs i64) i32 {
	if lhs == 0 { return 64 }
	return C.vox_wasm_clz64(u64(lhs))
}

pub fn binary_count_trailing_zeros_i32(lhs i32) i32 {
	if lhs == 0 { return 32 }
	return C.vox_wasm_ctz32(u32(lhs))
}

pub fn binary_count_trailing_zeros_i64(lhs i64) i32 {
	if lhs == 0 { return 64 }
	return C.vox_wasm_ctz64(u64(lhs))
}

pub fn binary_popcount_i8(lhs i8) i32 { return C.vox_wasm_popcount8(u8(lhs)) }

pub fn binary_popcount_i16(lhs i16) i32 { return C.vox_wasm_popcount16(u16(lhs)) }

pub fn binary_popcount_i32(lhs i32) i32 { return C.vox_wasm_popcount32(u32(lhs)) }

pub fn binary_popcount_i64(lhs i64) i32 { return C.vox_wasm_popcount64(u64(lhs)) }
