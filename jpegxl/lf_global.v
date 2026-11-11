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
	noise          ?NoiseParams
	spline_cache   ?SplineDrawCache
	patches        ?PatchesDictionary
}

// Parse the common LFGlobal state through modular transform planning. The owner
// then decodes section-zero channels and the dependent group sections. Feature
// Patch streams and incremental recovery remain separate services. Visible
// XYB VarDCT spline streams retain their initialized cache for the owner.
pub fn (mut reader BitReader) read_lf_global(file FileHeader, frame FrameHeader) !LfGlobalState {
	return reader.read_lf_global_refs(file, frame, []PatchReferenceInfo{})
}

// Patch dictionaries need the four reference slots saved by earlier frames.
// Without them a patch stream is rejected before any input is consumed.
pub fn (mut reader BitReader) read_lf_global_refs(file FileHeader, frame FrameHeader, refs []PatchReferenceInfo) !LfGlobalState {
	validate_modular_group_geometry(frame)!
	if (frame.has_patches() && (refs.len != 4 || frame.frame_type != .regular)) || (frame.has_splines() && (frame.encoding != .vardct
		|| frame.frame_type != .regular || !file.metadata.xyb_encoded
		|| u64(frame.width) * u64(frame.height) > 67108864))
		|| (frame.has_noise() && frame.encoding != .vardct) {
		return error('JPEG XL LF global requires unsupported feature streams')
	}
	colors := frame_color_channels(file, frame)
	infos := modular_frame_channel_info(file, frame, if frame.encoding == .vardct { 0 } else { colors })!
	limits := modular_stream_limits(infos)!
	patches := if frame.has_patches() {
		?PatchesDictionary(reader.read_patches(int(frame.width), int(frame.height), file.metadata.extra_channels.len, refs)!)
	} else { ?PatchesDictionary(none) }
	splines := if frame.has_splines() { ?Splines(reader.read_splines(frame.width * frame.height)!) } else { ?Splines(none) }
	noise := if frame.has_noise() { ?NoiseParams(reader.read_noise()!) } else { ?NoiseParams(none) }
	quantization := reader.read_lf_quant_factors()!
	mut context := ?VarDctLfContext(none)
	if frame.encoding == .vardct {
		quantizer := reader.read_quantizer_params()!
		block_context := reader.read_block_context_map()!
		correlation := reader.read_color_correlation_params()!
		context = VarDctLfContext{ quantizer: quantizer, lf_quant: quantization,
			block_context: block_context, color_correlation: correlation }
	}
	cache := if curves := splines {
		vardct := context or { return error('Missing JPEG XL spline color correlation') }
		size := frame.size()
		// Match the production helper's default options: ordinary precision
		// and the level-5 spline area limit, at the pre-upsampling frame size.
		?SplineDrawCache(curves.create_draw_cache(int(size.width), int(size.height), vardct.color_correlation, false, true)!)
	} else { ?SplineDrawCache(none) }
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
		modular_header: header, modular_plan: plan, noise: noise, spline_cache: cache, patches: patches }
}
