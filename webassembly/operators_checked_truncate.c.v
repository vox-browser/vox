// Copyright (c) 2021-2023, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Operators.h CheckedTruncate and AK/Checked.h's floating TypeBoundsChecker.
module webassembly

#include "@DIR/operators_checked_truncate_host.h"

fn C.vox_wasm_isinf_f32(f32) int

// The Source operand is first truncated in its original width. Promoting that
// float/double integer-valued result to f64 is exact; the Source long-double
// safe-cast window and round trip are identical for these original values.
fn checked_truncate_two_to_the(n u32) f64 {
	mut result := f64(1)
	for _ in 0 .. n { result *= 2 }
	return result
}

fn checked_truncate_within_i32(value f64) bool {
	boundary := checked_truncate_two_to_the(31)
	if !(value >= -boundary && value < boundary) { return false }
	truncated := i32(value)
	return f64(truncated) == value
}

pub fn binary_checked_truncate_f32_to_i32(lhs f32) !i32 {
	if C.vox_wasm_isnan_f32(lhs) != 0 || C.vox_wasm_isinf_f32(lhs) != 0 {
		return error('Truncation undefined behavior')
	}
	truncated := C.truncf(lhs)
	if !checked_truncate_within_i32(f64(truncated)) {
		return error('Truncation out of range')
	}
	return i32(truncated)
}

pub fn binary_checked_truncate_f64_to_i32(lhs f64) !i32 {
	if C.vox_wasm_isnan_f64(lhs) != 0 || C.vox_wasm_isinf_f64(lhs) != 0 {
		return error('Truncation undefined behavior')
	}
	truncated := C.trunc(lhs)
	if !checked_truncate_within_i32(f64(truncated)) {
		return error('Truncation out of range')
	}
	return i32(truncated)
}

fn checked_truncate_within_u32(value f64) bool {
	boundary := checked_truncate_two_to_the(32)
	if !(value >= 0 && value < boundary) { return false }
	truncated := u32(value)
	return f64(truncated) == value
}

pub fn binary_checked_truncate_f32_to_u32(lhs f32) !u32 {
	if C.vox_wasm_isnan_f32(lhs) != 0 || C.vox_wasm_isinf_f32(lhs) != 0 {
		return error('Truncation undefined behavior')
	}
	truncated := C.truncf(lhs)
	if !checked_truncate_within_u32(f64(truncated)) {
		return error('Truncation out of range')
	}
	return u32(truncated)
}

pub fn binary_checked_truncate_f64_to_u32(lhs f64) !u32 {
	if C.vox_wasm_isnan_f64(lhs) != 0 || C.vox_wasm_isinf_f64(lhs) != 0 {
		return error('Truncation undefined behavior')
	}
	truncated := C.trunc(lhs)
	if !checked_truncate_within_u32(f64(truncated)) {
		return error('Truncation out of range')
	}
	return u32(truncated)
}

fn checked_truncate_within_i64(value f64) bool {
	boundary := checked_truncate_two_to_the(63)
	if !(value >= -boundary && value < boundary) { return false }
	truncated := i64(value)
	return f64(truncated) == value
}

pub fn binary_checked_truncate_f32_to_i64(lhs f32) !i64 {
	if C.vox_wasm_isnan_f32(lhs) != 0 || C.vox_wasm_isinf_f32(lhs) != 0 {
		return error('Truncation undefined behavior')
	}
	truncated := C.truncf(lhs)
	if !checked_truncate_within_i64(f64(truncated)) {
		return error('Truncation out of range')
	}
	return i64(truncated)
}

pub fn binary_checked_truncate_f64_to_i64(lhs f64) !i64 {
	if C.vox_wasm_isnan_f64(lhs) != 0 || C.vox_wasm_isinf_f64(lhs) != 0 {
		return error('Truncation undefined behavior')
	}
	truncated := C.trunc(lhs)
	if !checked_truncate_within_i64(f64(truncated)) {
		return error('Truncation out of range')
	}
	return i64(truncated)
}

fn checked_truncate_within_u64(value f64) bool {
	boundary := checked_truncate_two_to_the(64)
	if !(value >= 0 && value < boundary) { return false }
	truncated := u64(value)
	return f64(truncated) == value
}

pub fn binary_checked_truncate_f32_to_u64(lhs f32) !u64 {
	if C.vox_wasm_isnan_f32(lhs) != 0 || C.vox_wasm_isinf_f32(lhs) != 0 {
		return error('Truncation undefined behavior')
	}
	truncated := C.truncf(lhs)
	if !checked_truncate_within_u64(f64(truncated)) {
		return error('Truncation out of range')
	}
	return u64(truncated)
}

pub fn binary_checked_truncate_f64_to_u64(lhs f64) !u64 {
	if C.vox_wasm_isnan_f64(lhs) != 0 || C.vox_wasm_isinf_f64(lhs) != 0 {
		return error('Truncation undefined behavior')
	}
	truncated := C.trunc(lhs)
	if !checked_truncate_within_u64(f64(truncated)) {
		return error('Truncation out of range')
	}
	return u64(truncated)
}
