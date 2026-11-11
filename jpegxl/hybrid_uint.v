// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

pub struct HybridUint {
pub:
	split_exponent u32
	msb_in_token   u32
	lsb_in_token   u32
}

fn ceil_log2(n int) int {
	mut value := math.max(0, n - 1)
	mut bits := 0
	for value > 0 {
		value >>= 1
		bits++
	}
	return bits
}

pub fn (mut b BitReader) read_hybrid_uint(log_alpha_size int) !HybridUint {
	if log_alpha_size < 0 || log_alpha_size > 15 { return error('Invalid JPEG XL alphabet size') }
	split := u32(b.read(ceil_log2(log_alpha_size + 1))!)
	// The source accepts nonminimal split exponents beyond log_alpha_size.
	// The selector is at most 15 here; allocation checks below still bound shifts.
	mut msb := u32(0)
	mut lsb := u32(0)
	if split != u32(log_alpha_size) {
		msb = u32(b.read(ceil_log2(int(split) + 1))!)
		if msb > split { return error('Invalid JPEG XL hybrid high bits') }
		lsb = u32(b.read(ceil_log2(int(split - msb) + 1))!)
	}
	if msb + lsb > split { return error('Invalid JPEG XL hybrid low bits') }
	return HybridUint{ split_exponent: split, msb_in_token: msb, lsb_in_token: lsb }
}

pub fn (config HybridUint) read(symbol u32, mut b BitReader) !u32 {
	if config.split_exponent > 31 || config.msb_in_token + config.lsb_in_token > config.split_exponent {
		return error('Invalid JPEG XL hybrid configuration')
	}
	return config.read_valid(symbol, mut b)
}

// read for a configuration with split_exponent <= 31 and
// msb_in_token + lsb_in_token <= split_exponent; nbits stays below 32.
@[inline]
fn (config HybridUint) read_valid(symbol u32, mut b BitReader) u32 {
	split := u32(1) << config.split_exponent
	if symbol < split { return symbol }
	in_token := config.msb_in_token + config.lsb_in_token
	nbits := (config.split_exponent - in_token + ((symbol - split) >> in_token)) & 31
	low := symbol & ((u32(1) << config.lsb_in_token) - 1)
	without_low := symbol >> config.lsb_in_token
	hi := (without_low & ((u32(1) << config.msb_in_token) - 1)) | (u32(1) << config.msb_in_token)
	bits := u32(b.read_bits_optimistic(int(nbits)))
	return (((hi << nbits) | bits) << config.lsb_in_token) | low
}

pub fn (config HybridUint) max_bits_for_symbol(symbol u32) int {
	split := u32(1) << config.split_exponent
	if symbol < split {
		return ceil_log2(int(symbol) + 1)
	}
	offset := (symbol - split) >> (config.lsb_in_token + config.msb_in_token)
	nbits := config.split_exponent - config.lsb_in_token - config.msb_in_token + offset
	if nbits >= 32 { return 32 }
	return int(config.split_exponent + offset + 1)
}
