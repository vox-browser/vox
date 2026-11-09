// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct LfGlobalState {
pub:
	quantization   LfQuantFactors
	vardct         ?VarDctLfContext
	tree           ?ModularTree
	modular_header ?ModularGroupHeader
	modular_plan   ModularTransformPlan
}

// Parse the common LFGlobal state through modular transform planning. The owner
// then decodes section-zero channels and the dependent group sections. Feature
// streams and incremental recovery are not supported by this entry point yet.
pub fn (mut reader BitReader) read_lf_global(file FileHeader, frame FrameHeader) !LfGlobalState {
	validate_modular_group_geometry(frame)!
	if frame.has_patches() || frame.has_splines() || frame.has_noise() {
		return error('JPEG XL LF global requires unsupported feature streams')
	}
	colors := frame_color_channels(file, frame)
	infos := modular_frame_channel_info(file, frame, if frame.encoding == .vardct { 0 } else { colors })!
	limits := modular_stream_limits(infos)!
	quantization := reader.read_lf_quant_factors()!
	mut context := ?VarDctLfContext(none)
	if frame.encoding == .vardct {
		quantizer := reader.read_quantizer_params()!
		block_context := reader.read_block_context_map()!
		correlation := reader.read_color_correlation_params()!
		context = VarDctLfContext{ quantizer: quantizer, lf_quant: quantization,
			block_context: block_context, color_correlation: correlation }
	}
	mut tree := ?ModularTree(none)
	if reader.read(1)! != 0 {
		pixels := u64(frame.width) * u64(frame.height)
		// Retain the existing bounded modular tree budget without overflowing
		// the source's pixels * channels size expression for invalid huge APIs.
		budget := if pixels > u64(131070) * 16 { u64(131070) } else {
			1024 + pixels * u64(colors + file.metadata.extra_channels.len) / 16
		}
		tree = reader.read_modular_tree(if budget < 131070 { int(budget) } else { 131070 })!
	}
	// A VarDCT frame with no extra channels has no modular global header.
	header := if infos.len == 0 { ?ModularGroupHeader(none) } else { ?ModularGroupHeader(reader.read_modular_group_header()!) }
	plan := plan_modular_transforms(infos, header or { ModularGroupHeader{} }, limits)!
	return LfGlobalState{ quantization: quantization, vardct: context, tree: tree,
		modular_header: header, modular_plan: plan }
}
