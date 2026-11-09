// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct HfChannelParameters {
pub:
	transform        HfTransform
	storage          ModularStorage
	shift            u32
	nonzeros         u32
	histogram_offset int
}

// Accumulate one component of one progressive pass. The entropy reader belongs
// to the enclosing group/pass; its final state is checked after all components.
pub fn decode_hf_channel(params HfChannelParameters, permutation Permutation, histograms Histograms, mut reader BitReader, mut symbols SymbolReader, mut coefficients []i32) ! {
	blocks := params.transform.covered_blocks()
	num_blocks := blocks[0] * blocks[1]
	num_coefficients := num_blocks * 64
	if params.shift > 31 || params.nonzeros > u32(num_coefficients - num_blocks)
		|| params.histogram_offset < 0 || params.histogram_offset > histograms.context_map.len - zero_density_context_limit
		|| permutation.values.len != num_coefficients || coefficients.len != num_coefficients {
		return error('Invalid JPEG XL HF coefficient parameters')
	}
	mut seen := []bool{len: num_coefficients}
	for index in permutation.values {
		if index >= u32(num_coefficients) || seen[int(index)] {
			return error('Invalid JPEG XL HF coefficient permutation')
		}
		seen[int(index)] = true
	}
	if params.storage == .signed16 {
		for value in coefficients {
			if value < -32768 || value > 32767 { return error('Invalid JPEG XL signed16 coefficient storage') }
		}
	}
	mut nonzeros := params.nonzeros
	mut previous := nonzeros <= u32(num_coefficients / 16)
	log_num_blocks := ceil_log2(num_blocks)
	for k in num_blocks .. num_coefficients {
		if nonzeros == 0 { break }
		context := params.histogram_offset + zero_density_context(nonzeros, u32(k), log_num_blocks, previous)!
		value := symbols.read_signed(histograms, context, mut reader)!
		shifted := i32(u32(value) << params.shift)
		previous = shifted != 0
		if previous { nonzeros-- }
		index := int(permutation.values[k])
		coefficients[index] = modular_storage_value(i32(u32(coefficients[index]) + u32(shifted)), params.storage)
	}
	if nonzeros != 0 { return error('Residual JPEG XL HF nonzeros') }
}
