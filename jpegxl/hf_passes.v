// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct HfPassState {
pub:
	coefficient_orders []Permutation
	histograms         Histograms
}

pub struct HfPasses {
pub:
	histogram_sets      u32
	passes              []HfPassState
	coefficient_storage ModularStorage
}

// Read the HFGlobal fields following its dequantization matrices. Coefficient
// buffers belong to group decoding and are allocated only when needed.
pub fn (mut reader BitReader) read_hf_passes(num_groups u32, frame_passes Passes, block_contexts int) !HfPasses {
	if num_groups < 1 || num_groups > 65536 || frame_passes.count < 1 || frame_passes.count > 11
		|| frame_passes.shifts.len > int(frame_passes.count) - 1 || frame_passes.shifts.any(it > 3)
		|| block_contexts < 1 || block_contexts > 16 {
		return error('Invalid JPEG XL HF pass dimensions')
	}
	sets := u32(reader.read(ceil_log2(int(num_groups)))!) + 1
	contexts := u64(sets) * u64(block_contexts) * u64(nonzero_context_buckets + zero_density_context_count)
	padding := zero_density_context_limit - zero_density_context_count
	// This layer retains the entropy reader's existing bounded context budget.
	if contexts + u64(padding) > 65536 { return error('JPEG XL HF histogram context budget exceeded') }
	mut passes := []HfPassState{cap: int(frame_passes.count)}
	mut maximum_bits := 0
	for pass in 0 .. int(frame_passes.count) {
		used_orders := match reader.read(2)! {
			0 { u32(0x5f) }
			1 { u32(0x13) }
			2 { u32(0) }
			else { u32(reader.read(coefficient_order_count)!) }
		}
		orders := reader.read_coefficient_orders(used_orders)!
		mut histograms := reader.read_histograms(int(contexts), true)!
		histograms.resize(int(contexts) + padding)!
		shift := if pass < frame_passes.shifts.len { int(frame_passes.shifts[pass]) } else { 0 }
		bits := histograms.max_num_bits()! + shift
		if bits > maximum_bits { maximum_bits = bits }
		passes << HfPassState{ coefficient_orders: orders, histograms: histograms }
	}
	return HfPasses{
		histogram_sets: sets
		passes: passes
		coefficient_storage: if maximum_bits < 16 { ModularStorage.signed16 } else { ModularStorage.signed32 }
	}
}
