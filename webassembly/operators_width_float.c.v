// Copyright (c) 2021-2023, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Operators.h Promote and Demote; Source nan canonicalization FIXME retained.
module webassembly

#include "@DIR/operators_width_float_host.h"

fn C.vox_wasm_isinf_f64(f64) int
fn C.vox_wasm_empty_nan_f64() f64
fn C.vox_wasm_empty_nan_f32() f32
fn C.vox_wasm_huge_f32() f32

pub fn binary_promote_f32_to_f64(lhs f32) f64 {
	if C.vox_wasm_isnan_f32(lhs) != 0 { return C.vox_wasm_empty_nan_f64() }
	return f64(lhs)
}

pub fn binary_demote_f64_to_f32(lhs f64) f32 {
	if C.vox_wasm_isnan_f64(lhs) != 0 { return C.vox_wasm_empty_nan_f32() }
	if C.vox_wasm_isinf_f64(lhs) != 0 { return C.copysignf(C.vox_wasm_huge_f32(), f32(lhs)) }
	return f32(lhs)
}
