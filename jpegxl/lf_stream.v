// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct VarDctLfContext {
pub:
	quantizer         QuantizerParams
	lf_quant          LfQuantFactors
	color_correlation ColorCorrelationParams
	block_context     BlockContextMap
}

pub fn (frame FrameHeader) vardct_lf_stream_id(group u64) !u32 {
	checked_vardct_lf_rect(frame, group)!
	id := 1 + group
	if id > 4294967295 { return error('JPEG XL VarDCT LF stream ID overflow') }
	return u32(id)
}

// Read the VarDCT LF portion before a group's modular LF and HF metadata.
// Returned planes use LF-group-local, already subsampled block coordinates.
pub fn (mut reader BitReader) read_vardct_lf(frame FrameHeader, group u64, depth BitDepth, context VarDctLfContext, storage ModularStorage, global_tree ?ModularTree) !VarDctLfResult {
	r := checked_vardct_lf_rect(frame, group)!
	stream_id := frame.vardct_lf_stream_id(group)!
	mut hs := [3]u32{}
	mut vs := [3]u32{}
	for c in 0 .. 3 {
		hs[c] = frame.hshift(c)!
		vs[c] = frame.vshift(c)!
	}
	extra_precision := u32(reader.read(2)!)
	mut infos := []ModularChannelInfo{cap: 3}
	for c in [1, 0, 2] {
		infos << ModularChannelInfo{ width: int(r.width >> hs[c]), height: int(r.height >> vs[c]),
			shift: ModularShift{}, bit_depth: depth }
	}
	channels := reader.decode_modular_stream(infos, storage, stream_id, none, global_tree)!
	return reconstruct_vardct_lf(channels, VarDctLfParameters{
		width: int(r.width)
		height: int(r.height)
		horizontal_shift: hs
		vertical_shift: vs
		extra_precision: extra_precision
		quantizer: context.quantizer
		lf_quant: context.lf_quant
		color_correlation: context.color_correlation
		block_context: context.block_context
	})
}
