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
	num_coefficients := blocks[0] * blocks[1] * 64
	validate_hf_coefficient_order(permutation, num_coefficients)!
	if params.storage == .signed16 {
		for value in coefficients {
			if value < -32768 || value > 32767 { return error('Invalid JPEG XL signed16 coefficient storage') }
		}
	}
	decode_hf_coefficients(params, permutation, histograms, mut reader, mut symbols, mut coefficients)!
}

// An order must be a permutation of every coefficient position of its shape.
fn validate_hf_coefficient_order(permutation Permutation, num_coefficients int) ! {
	if permutation.values.len != num_coefficients {
		return error('Invalid JPEG XL HF coefficient parameters')
	}
	mut seen := []bool{len: num_coefficients}
	for index in permutation.values {
		if index >= u32(num_coefficients) || seen[int(index)] {
			return error('Invalid JPEG XL HF coefficient permutation')
		}
		seen[int(index)] = true
	}
}

// The coefficient loop for a validated order and storage. The group decoder
// validates each order once and keeps storage in range through
// modular_storage_value, so blocks only recheck their scalar parameters.
// Indices are a validated permutation below coefficients.len, and the zero
// density coordinates stay in 1..63: nonzeros never exceeds 63 per block and
// k starts at the block count.
@[direct_array_access]
fn decode_hf_coefficients(params HfChannelParameters, permutation Permutation, histograms Histograms, mut reader BitReader, mut symbols SymbolReader, mut coefficients []i32) ! {
	blocks := params.transform.covered_blocks()
	num_blocks := blocks[0] * blocks[1]
	num_coefficients := num_blocks * 64
	if params.shift > 31 || params.nonzeros > u32(num_coefficients - num_blocks)
		|| params.histogram_offset < 0 || params.histogram_offset > histograms.context_map.len - zero_density_context_limit
		|| permutation.values.len != num_coefficients || coefficients.len != num_coefficients || num_blocks > 1024 {
		return error('Invalid JPEG XL HF coefficient parameters')
	}
	mut nonzeros := params.nonzeros
	mut previous := nonzeros <= u32(num_coefficients / 16)
	log_num_blocks := ceil_log2(num_blocks)
	block_mask := (u32(1) << log_num_blocks) - 1
	for k in num_blocks .. num_coefficients {
		if nonzeros == 0 { break }
		nz := (nonzeros >> log_num_blocks) + if nonzeros & block_mask == 0 { u32(0) } else { u32(1) }
		frequency := u32(k) >> log_num_blocks
		context := params.histogram_offset + (coefficient_nonzero_context[int(nz)]
			+ coefficient_frequency_context[int(frequency)]) * 2 + if previous { 1 } else { 0 }
		value := symbols.read_signed(&histograms, context, mut reader)!
		shifted := i32(u32(value) << params.shift)
		previous = shifted != 0
		if previous { nonzeros-- }
		index := int(permutation.values[k])
		coefficients[index] = modular_storage_value(i32(u32(coefficients[index]) + u32(shifted)), params.storage)
	}
	if nonzeros != 0 { return error('Residual JPEG XL HF nonzeros') }
}
