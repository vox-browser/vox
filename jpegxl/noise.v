// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct NoiseParams {
pub:
	lut [8]f32
}

pub fn (mut reader BitReader) read_noise() !NoiseParams {
	mut lut := [8]f32{}
	for i in 0 .. 8 { lut[i] = f32(reader.read(10)!) / f32(1024) }
	return NoiseParams{ lut: lut }
}

// Upstream adapts https://github.com/vpxyz/xorshift/tree/master/xorshift128plus
// under the MIT license. Eight interleaved lanes preserve its field ordering.
struct NoiseRng {
mut:
	s0 [8]u64
	s1 [8]u64
}

fn noise_split_mix_64(input u64) u64 {
	mut z := (input ^ (input >> 30)) * u64(0xBF58476D1CE4E5B9)
	z = (z ^ (z >> 27)) * u64(0x94D049BB133111EB)
	return z ^ (z >> 31)
}

fn new_noise_rng_single(seed u64) NoiseRng {
	mut rng := NoiseRng{}
	rng.s0[0] = noise_split_mix_64(seed + u64(0x9E3779B97F4A7C15))
	rng.s1[0] = noise_split_mix_64(rng.s0[0])
	for i in 1 .. 8 {
		rng.s0[i] = noise_split_mix_64(rng.s1[i - 1])
		rng.s1[i] = noise_split_mix_64(rng.s0[i])
	}
	return rng
}

fn new_noise_rng(seed1 u32, seed2 u32, seed3 u32, seed4 u32) NoiseRng {
	mut rng := NoiseRng{}
	rng.s0[0] = noise_split_mix_64(((u64(seed1) << 32) + u64(seed2)) + u64(0x9E3779B97F4A7C15))
	rng.s1[0] = noise_split_mix_64(((u64(seed3) << 32) + u64(seed4)) + u64(0x9E3779B97F4A7C15))
	for i in 1 .. 8 {
		rng.s0[i] = noise_split_mix_64(rng.s0[i - 1])
		rng.s1[i] = noise_split_mix_64(rng.s1[i - 1])
	}
	return rng
}

fn (mut rng NoiseRng) next_block() [8]u64 {
	mut output := [8]u64{}
	for i in 0 .. 8 {
		mut s1 := rng.s0[i]
		s0 := rng.s1[i]
		rng.s0[i] = s0
		output[i] = s1 + s0
		s1 ^= s1 << 23
		rng.s1[i] = s1 ^ s0 ^ (s1 >> 18) ^ (s0 >> 5)
	}
	return output
}
