// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct HfGlobalState {
pub:
	matrices DequantMatrices
	passes   HfPasses
}

// Parse HFGlobal after every LF group's metadata is available. Coefficient
// storage and EPF sigma are allocated by the frame owner when needed.
pub fn (mut reader BitReader) read_hf_global(frame FrameHeader, lf LfGlobalState, storage ModularStorage) !HfGlobalState {
	checked_vardct_lf_rect(frame, 0)!
	context := lf.vardct or { return error('JPEG XL HF global requires VarDCT LF state') }
	groups := frame.num_groups()
	if groups > 65536 { return error('JPEG XL HF group count exceeds context budget') }
	matrices := reader.read_dequant_matrices(frame, storage, lf.tree)!
	passes := reader.read_hf_passes(u32(groups), frame.passes, context.block_context.num_contexts)!
	return HfGlobalState{ matrices: matrices, passes: passes }
}
