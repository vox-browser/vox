// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

fn fma_significand(bits u32) (u64, int) {
	exponent := int((bits >> 23) & 255)
	return if exponent == 0 {
		u64(bits & 0x7fffff), -149
	} else {
		u64((bits & 0x7fffff) | 0x800000), exponent - 150
	}
}

fn fma_fixed(value u64, shift int) [9]u64 {
	mut limbs := [9]u64{}
	word := shift / 64
	offset := shift % 64
	limbs[word] = value << offset
	if offset != 0 && word + 1 < 9 { limbs[word + 1] = value >> (64 - offset) }
	return limbs
}

fn fma_fixed_below(limbs [9]u64, cut int) bool {
	for i in 0 .. cut / 64 { if limbs[i] != 0 { return true } }
	return cut % 64 != 0 && limbs[cut / 64] & ((u64(1) << (cut % 64)) - 1) != 0
}

// Exact finite product/addition in units of 2^-298, rounded once to binary32.
// Nine limbs cover the largest finite product without allocation or native FMA.
fn fused_f32_exact(a f32, b f32, c f32) f32 {
	ab := math.f32_bits(a)
	bb := math.f32_bits(b)
	cb := math.f32_bits(c)
	am, ae := fma_significand(ab)
	bm, be := fma_significand(bb)
	cm, ce := fma_significand(cb)
	left := fma_fixed(am * bm, ae + be + 298)
	right := fma_fixed(cm, ce + 298)
	mut sign := (ab ^ bb) & 0x80000000
	mut limbs := [9]u64{}
	if sign == cb & 0x80000000 {
		mut carry := u64(0)
		for i in 0 .. 9 {
			part := left[i] + right[i]
			limbs[i] = part + carry
			carry = if part < left[i] || limbs[i] < part { 1 } else { 0 }
		}
	} else {
		mut order := 0
		for i := 8; i >= 0; i-- {
			if left[i] != right[i] {
				order = if left[i] > right[i] { 1 } else { -1 }
				break
			}
		}
		if order == 0 { return 0 }
		larger := if order > 0 { left } else { right }
		smaller := if order > 0 { right } else { left }
		if order < 0 { sign = cb & 0x80000000 }
		mut borrow := u64(0)
		for i in 0 .. 9 {
			limbs[i] = larger[i] - smaller[i] - borrow
			borrow = if larger[i] < smaller[i] || (larger[i] == smaller[i] && borrow != 0) {
				1
			} else {
				0
			}
		}
	}
	mut highest := -1
	for i := 8; i >= 0; i-- {
		if limbs[i] == 0 { continue }
		mut v := limbs[i]
		highest = i * 64
		for v > 1 {
			v >>= 1
			highest++
		}
		break
	}
	if highest < 0 { return math.f32_from_bits(sign) }
	mut exponent := highest - 298
	cut := if exponent < -126 { 149 } else { highest - 23 }
	word := cut / 64
	offset := cut % 64
	mut rounded := limbs[word] >> offset
	if offset != 0 && word + 1 < 9 { rounded |= limbs[word + 1] << (64 - offset) }
	guard := (limbs[(cut - 1) / 64] >> ((cut - 1) % 64)) & 1 != 0
	if guard && (rounded & 1 != 0 || fma_fixed_below(limbs, cut - 1)) { rounded++ }
	if exponent < -126 { return math.f32_from_bits(sign | u32(rounded)) }
	if rounded >= 0x1000000 {
		rounded >>= 1
		exponent++
	}
	if exponent > 127 { return math.f32_from_bits(sign | 0x7f800000) }
	return math.f32_from_bits(sign | (u32(exponent + 127) << 23) | (u32(rounded) & 0x7fffff))
}

fn C.fmaf(a f32, b f32, c f32) f32

// One correctly rounded binary32 multiply-add (IEEE 754 fusedMultiplyAdd).
// libm's fmaf is exact on every target and compiles to a single instruction
// where the CPU has FMA. NaN results are canonicalized, matching the source
// comparison data; fused_f32_exact remains the portable limb oracle.
@[inline]
fn fused_f32(a f32, b f32, c f32) f32 {
	result := C.fmaf(a, b, c)
	if math.is_nan(result) { return math.f32_from_bits(0x7fc00000) }
	return result
}
