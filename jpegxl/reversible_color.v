// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

fn rct_permute(values [3]i32, permutation u32) [3]i32 {
	return match permutation {
		0 { values }
		1 { [values[2], values[0], values[1]]! }
		2 { [values[1], values[2], values[0]]! }
		3 { [values[0], values[2], values[1]]! }
		4 { [values[1], values[0], values[2]]! }
		else { [values[2], values[1], values[0]]! }
	}
}

fn rct_add(a i32, b i32) i32 { return i32(i64(a) + i64(b)) }

fn rct_sub(a i32, b i32) i32 { return i32(i64(a) - i64(b)) }

fn rct_add16(a i16, b i16) i16 { return i16(i32(a) + i32(b)) }

fn rct_sub16(a i16, b i16) i16 { return i16(i32(a) - i32(b)) }

fn rct_sample32(kind u32, v0 i32, v1 i32, v2 i32) [3]i32 {
	mut values := [v0, v1, v2]!
	match kind % 7 {
		0 {}
		1 { values[2] = rct_add(v2, v0) }
		2 { values[1] = rct_add(v1, v0) }
		3 {
			values[1] = rct_add(v1, v0)
			values[2] = rct_add(v2, v0)
		}
		4 { values[1] = rct_add(v1, rct_add(v0, v2) >> 1) }
		5 {
			values[2] = rct_add(v0, v2)
			values[1] = rct_add(v1, rct_add(v0, values[2]) >> 1)
		}
		else {
			y := rct_sub(v0, v2 >> 1)
			values[1] = rct_add(v2, y)
			values[2] = rct_sub(y, v1 >> 1)
			values[0] = rct_add(values[2], v1)
		}
	}
	return rct_permute(values, kind / 7)
}

fn rct_sample16(kind u32, v0 i16, v1 i16, v2 i16) [3]i16 {
	mut values := [v0, v1, v2]!
	match kind % 7 {
		0 {}
		1 { values[2] = rct_add16(v2, v0) }
		2 { values[1] = rct_add16(v1, v0) }
		3 {
			values[1] = rct_add16(v1, v0)
			values[2] = rct_add16(v2, v0)
		}
		4 { values[1] = rct_add16(v1, i16((i32(v0) + i32(v2)) >> 1)) }
		5 {
			values[2] = rct_add16(v0, v2)
			values[1] = rct_add16(v1, i16((i32(v0) + i32(values[2])) >> 1))
		}
		else {
			y := rct_sub16(v0, v2 >> 1)
			values[1] = rct_add16(v2, y)
			values[2] = rct_sub16(y, v1 >> 1)
			values[0] = rct_add16(values[2], v1)
		}
	}
	permuted := rct_permute([i32(values[0]), i32(values[1]), i32(values[2])]!, kind / 7)
	return [i16(permuted[0]), i16(permuted[1]), i16(permuted[2])]!
}

pub fn inverse_rct_sample(kind u32, v0 i32, v1 i32, v2 i32) ![3]i32 {
	if kind >= 42 { return error('Invalid JPEG XL reversible color transform') }
	return rct_sample32(kind, v0, v1, v2)
}

pub fn inverse_rct_sample16(kind u32, v0 i16, v1 i16, v2 i16) ![3]i16 {
	if kind >= 42 { return error('Invalid JPEG XL reversible color transform') }
	return rct_sample16(kind, v0, v1, v2)
}

// Rows must be separate equally sized channel buffers. Validate before mutation.
pub fn inverse_rct_rows(mut first []i32, mut second []i32, mut third []i32, kind u32) ! {
	if kind >= 42 || first.len != second.len || first.len != third.len {
		return error('Invalid JPEG XL reversible color transform rows')
	}
	for x in 0 .. first.len {
		out := rct_sample32(kind, first[x], second[x], third[x])
		first[x] = out[0]
		second[x] = out[1]
		third[x] = out[2]
	}
}

pub fn inverse_rct_rows16(mut first []i16, mut second []i16, mut third []i16, kind u32) ! {
	if kind >= 42 || first.len != second.len || first.len != third.len {
		return error('Invalid JPEG XL reversible color transform rows')
	}
	for x in 0 .. first.len {
		out := rct_sample16(kind, first[x], second[x], third[x])
		first[x] = out[0]
		second[x] = out[1]
		third[x] = out[2]
	}
}
