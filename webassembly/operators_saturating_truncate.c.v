// Copyright (c) 2021-2023, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Operators.h SaturatingTruncate. Source i64 edge-value FIXME is retained.
module webassembly

pub fn binary_saturating_truncate_f32_to_i32(lhs f32) i32 {
	minimum := i32(-2147483647) - 1
	maximum := i32(2147483647)
	if C.vox_wasm_isnan_f32(lhs) != 0 { return i32(0) }
	if C.vox_wasm_isinf_f32(lhs) != 0 {
		if lhs < 0 { return minimum }
		return maximum
	}
	truncated := C.truncf(lhs)
	if truncated < f32(minimum) { return minimum }
	if truncated >= f32(maximum) { return maximum }
	return i32(truncated)
}

pub fn binary_saturating_truncate_f64_to_i32(lhs f64) i32 {
	minimum := i32(-2147483647) - 1
	maximum := i32(2147483647)
	if C.vox_wasm_isnan_f64(lhs) != 0 { return i32(0) }
	if C.vox_wasm_isinf_f64(lhs) != 0 {
		if lhs < 0 { return minimum }
		return maximum
	}
	truncated := C.trunc(lhs)
	if truncated < f64(minimum) { return minimum }
	if truncated >= f64(maximum) { return maximum }
	return i32(truncated)
}

pub fn binary_saturating_truncate_f32_to_u32(lhs f32) u32 {
	minimum := u32(0)
	maximum := u32(0xffffffff)
	if C.vox_wasm_isnan_f32(lhs) != 0 { return u32(0) }
	if C.vox_wasm_isinf_f32(lhs) != 0 {
		if lhs < 0 { return minimum }
		return maximum
	}
	truncated := C.truncf(lhs)
	if truncated < f32(minimum) { return minimum }
	if truncated >= f32(maximum) { return maximum }
	return u32(truncated)
}

pub fn binary_saturating_truncate_f64_to_u32(lhs f64) u32 {
	minimum := u32(0)
	maximum := u32(0xffffffff)
	if C.vox_wasm_isnan_f64(lhs) != 0 { return u32(0) }
	if C.vox_wasm_isinf_f64(lhs) != 0 {
		if lhs < 0 { return minimum }
		return maximum
	}
	truncated := C.trunc(lhs)
	if truncated < f64(minimum) { return minimum }
	if truncated >= f64(maximum) { return maximum }
	return u32(truncated)
}

pub fn binary_saturating_truncate_f32_to_i64(lhs f32) i64 {
	minimum := i64(-9223372036854775807) - 1
	maximum := i64(9223372036854775807)
	if C.vox_wasm_isnan_f32(lhs) != 0 { return i64(0) }
	if C.vox_wasm_isinf_f32(lhs) != 0 {
		if lhs < 0 { return minimum }
		return maximum
	}
	truncated := C.truncf(lhs)
	if truncated < f32(minimum) { return minimum }
	if truncated >= f32(maximum) { return maximum }
	return i64(truncated)
}

pub fn binary_saturating_truncate_f64_to_i64(lhs f64) i64 {
	minimum := i64(-9223372036854775807) - 1
	maximum := i64(9223372036854775807)
	if C.vox_wasm_isnan_f64(lhs) != 0 { return i64(0) }
	if C.vox_wasm_isinf_f64(lhs) != 0 {
		if lhs < 0 { return minimum }
		return maximum
	}
	truncated := C.trunc(lhs)
	if truncated < f64(minimum) { return minimum }
	if truncated >= f64(maximum) { return maximum }
	return i64(truncated)
}

pub fn binary_saturating_truncate_f32_to_u64(lhs f32) u64 {
	minimum := u64(0)
	maximum := u64(0xffffffffffffffff)
	if C.vox_wasm_isnan_f32(lhs) != 0 { return u64(0) }
	if C.vox_wasm_isinf_f32(lhs) != 0 {
		if lhs < 0 { return minimum }
		return maximum
	}
	truncated := C.truncf(lhs)
	if truncated < f32(minimum) { return minimum }
	if truncated >= f32(maximum) { return maximum }
	return u64(truncated)
}

pub fn binary_saturating_truncate_f64_to_u64(lhs f64) u64 {
	minimum := u64(0)
	maximum := u64(0xffffffffffffffff)
	if C.vox_wasm_isnan_f64(lhs) != 0 { return u64(0) }
	if C.vox_wasm_isinf_f64(lhs) != 0 {
		if lhs < 0 { return minimum }
		return maximum
	}
	truncated := C.trunc(lhs)
	if truncated < f64(minimum) { return minimum }
	if truncated >= f64(maximum) { return maximum }
	return u64(truncated)
}
