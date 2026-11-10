// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct VarDctFramePlanes {
pub:
	planes    [3]FloatPlane
	epf_maps  VarDctEpfMaps
	quantizer QuantizerParams
	extra_channels []ModularChannel
	noise          ?NoiseParams
	color_correlation ColorCorrelationParams
	spline_cache      ?SplineDrawCache
	patches           ?PatchesDictionary
}

fn validate_vardct_frame_subset(file FileHeader, frame FrameHeader) ! {
	if frame.has_lf_frame() || frame.lf_level != 0 || frame.upsampling != 1 || file.metadata.extra_channels.len != 0 {
		return error('JPEG XL VarDCT frame requires explicit LF reference ownership')
	}
	validate_vardct_frame_reference(file, frame, none)!
}

fn validate_vardct_frame_reference(file FileHeader, frame FrameHeader, reference ?[3]FloatPlane) ! {
	checked_vardct_lf_rect(frame, 0)!
	if file.metadata.extra_channels.len > 1
		|| frame.extra_upsampling.len != file.metadata.extra_channels.len || (frame.lf_level != 0 && frame.frame_type != .lf)
		|| (frame.has_lf_frame() && frame.lf_level >= 4) {
		return error('JPEG XL VarDCT frame requires unsupported sampling or extra channels')
	}
	if !frame.is444() && (file.metadata.xyb_encoded || !frame.do_ycbcr || frame.has_lf_frame()
		|| frame.frame_type == .lf || frame.should_do_adaptive_lf_smoothing()) {
		return error('Unsupported JPEG XL subsampled VarDCT frame services')
	}
	for c in 0 .. 3 {
		if frame.hshift(c)! > 1 || frame.vshift(c)! > 1 {
			return error('Unsupported JPEG XL chroma sampling factor')
		}
	}
	if frame.has_noise() && (!file.metadata.xyb_encoded || frame.frame_type != .regular) {
		return error('JPEG XL noise output requires a visible XYB VarDCT frame')
	}
	for i,extra in file.metadata.extra_channels {
		if extra.kind != .alpha || extra.dimension_shift != 0 || extra.bit_depth.floating_point
			|| extra.bit_depth.bits_per_sample != 8 || frame.extra_upsampling[i] !in [u32(1), 2, 4, 8]
			|| frame.upsampling !in [u32(1), 2, 4, 8] || frame.extra_upsampling[i] < frame.upsampling {
			return error('JPEG XL VarDCT extra channels require one supported 8-bit alpha plane')
		}
	}
	if frame.has_lf_frame() != (reference != none) { return error('Missing or unexpected JPEG XL LF reference') }
	size := frame.size_padded()
	actual := frame.size()
	if size.width < actual.width || size.height < actual.height || size.width == 0 || size.height == 0
		|| u64(size.width) * u64(size.height) > 67108864 / 3 {
		return error('JPEG XL VarDCT frame exceeds the plane sample budget')
	}
	if u64(size.width)*u64(size.height)*3 + u64(actual.width)*u64(actual.height)*u64(file.metadata.extra_channels.len) > 67108864 {
		return error('JPEG XL VarDCT color and extra planes exceed the sample budget')
	}
	if planes := reference {
		blocks := frame.size_blocks()
		for plane in planes {
			plane.validate()!
			if plane.width != int(blocks.width) || plane.height != int(blocks.height) {
				return error('Incorrect JPEG XL LF reference geometry')
			}
		}
	}
}

fn referenced_lf_group(frame FrameHeader, group u64, reference [3]FloatPlane) !VarDctLfResult {
	r := checked_vardct_lf_rect(frame, group)!
	mut planes := []FloatPlane{cap: 3}
	for plane in reference { planes << crop_float_plane(plane, int(r.x), int(r.y), int(r.width), int(r.height))! }
	// The source leaves the LF quant-context map zero-initialized when the
	// LF modular stream is replaced by a rendered reference frame.
	return VarDctLfResult{ width: int(r.width), height: int(r.height), planes: planes,
		quant_lf_contexts: []u8{len: int(r.width) * int(r.height)} }
}

// Assemble complete component planes before chroma upsampling/restoration.
// All progressive passes are consumed. This entry point has no LF dependency;
// the reference-aware entry point also handles non-visible LF frame levels.
pub fn decode_vardct_frame(file FileHeader, frame FrameHeader, storage ModularStorage, mut sections []BitReader) !VarDctFramePlanes {
	validate_vardct_frame_subset(file, frame)!
	return decode_vardct_frame_with_lf(file, frame, storage, none, mut sections)
}

pub fn decode_vardct_frame_with_lf(file FileHeader, frame FrameHeader, storage ModularStorage, reference ?[3]FloatPlane, mut sections []BitReader) !VarDctFramePlanes {
	return decode_vardct_frame_with_refs(file, frame, storage, reference, []PatchReferenceInfo{}, mut sections)
}

pub fn decode_vardct_frame_with_refs(file FileHeader, frame FrameHeader, storage ModularStorage, reference ?[3]FloatPlane, patch_refs []PatchReferenceInfo, mut sections []BitReader) !VarDctFramePlanes {
	validate_vardct_frame_reference(file, frame, reference)!
	if sections.len != int(frame.num_toc_entries()) { return error('Incorrect JPEG XL VarDCT section count') }
	combined := sections.len == 1
	global := sections[0].read_lf_global_refs(file, frame, patch_refs)!
	context := global.vardct or { return error('Missing JPEG XL VarDCT LF context') }
	mut modular := new_modular_frame_state(global.modular_plan, frame)!
	unused_global := modular.read_global(mut sections[0], global.modular_header, global.tree, storage)!
	if !combined { finish_modular_section(mut sections[0], 0, unused_global && global.modular_header != none)! }
	mut metadata := []HfMetadata{cap: int(frame.num_lf_groups())}
	mut low := []VarDctLfResult{cap: int(frame.num_lf_groups())}
	for group in u64(0) .. frame.num_lf_groups() {
		index := if combined { 0 } else { 1 + int(group) }
		low << if planes := reference {
			referenced_lf_group(frame, group, planes)!
		} else {
			sections[index].read_vardct_lf(frame, group, file.metadata.bit_depth, context, storage, global.tree)!
		}
		modular.read_group(mut sections[index], frame, true, group, 0, global.tree, storage)!
		metadata << sections[index].read_hf_metadata(frame, group, file.metadata.bit_depth, storage, global.tree)!
		if !combined { finish_modular_section(mut sections[index], index, false)! }
	}
	blocks := frame.size_blocks()
	bw := int(blocks.width)
	bh := int(blocks.height)
	mut hs := [3]u32{}
	mut vs := [3]u32{}
	mut low_samples := [3][]f32{}
	for c in 0 .. 3 {
		hs[c] = frame.hshift(c)!
		vs[c] = frame.vshift(c)!
		low_samples[c] = []f32{len: (bw >> hs[c]) * (bh >> vs[c])}
	}
	mut raw_quant := []i32{len: bw * bh}
	mut transforms := []u8{len: bw * bh}
	mut sharpness := []u8{len: bw * bh}
	for group in 0 .. low.len {
		r := frame.lf_group_rect(u64(group))!
		for c in 0 .. 3 {
			for y in 0 .. int(r.height >> vs[c]) {
				for x in 0 .. int(r.width >> hs[c]) {
					src := y * low[group].planes[c].width + x
					dst := (int(r.y >> vs[c]) + y) * (bw >> hs[c]) + int(r.x >> hs[c]) + x
					low_samples[c][dst] = low[group].planes[c].samples[src]
				}
			}
		}
		for y in 0 .. int(r.height) {
			for x in 0 .. int(r.width) {
				src := y * int(r.width) + x
				dst := (int(r.y) + y) * bw + int(r.x) + x
				raw_quant[dst] = metadata[group].raw_quant[src]
				transforms[dst] = metadata[group].transform_ids[src]
				sharpness[dst] = metadata[group].sharpness[src]
			}
		}
	}
	mut lf_planes := []FloatPlane{cap: 3}
	for c in 0 .. 3 { lf_planes << FloatPlane{ width: bw >> hs[c], height: bh >> vs[c], samples: low_samples[c] } }
	if frame.should_do_adaptive_lf_smoothing() {
		inverse := context.quantizer.inverse_quant_lf()
		factors := context.lf_quant.quant_factors
		lf_planes = adaptive_lf_smoothing(lf_planes, [inverse * factors[0], inverse * factors[1], inverse * factors[2]]!)!
	}
	for group in 0 .. low.len {
		r := frame.lf_group_rect(u64(group))!
		mut planes := []FloatPlane{cap: 3}
		for c in 0 .. 3 { planes << crop_float_plane(lf_planes[c], int(r.x >> hs[c]), int(r.y >> vs[c]), int(r.width >> hs[c]), int(r.height >> vs[c]))! }
		low[group] = VarDctLfResult{ ...low[group], planes: planes }
	}
	hf_index := if combined { 0 } else { 1 + low.len }
	hf := sections[hf_index].read_hf_global(frame, global, storage)!
	if !combined { finish_modular_section(mut sections[hf_index], hf_index, false)! }
	size := frame.size_padded()
	w := int(size.width)
	h := int(size.height)
	mut samples := [3][]f32{}
	for c in 0 .. 3 { samples[c] = []f32{len: (w >> hs[c]) * (h >> vs[c])} }
	for group in u64(0) .. frame.num_groups() {
		owner := frame.vardct_lf_group_for_group(group)!
		data := select_vardct_group(frame, group, owner, metadata[int(owner)], low[int(owner)])!
		mut coefficients := [3][]i32{}
		for c in 0 .. 3 { coefficients[c] = []i32{len: data.maps.width * data.maps.height * 64} }
		mut inputs := []HfGroupInput{cap: int(frame.passes.count)}
		for pass in 0 .. int(frame.passes.count) {
			index := if combined { 0 } else { 2 + low.len + pass * int(frame.num_groups()) + int(group) }
			inputs << HfGroupInput{ pass: pass, reader: sections[index] }
		}
		decode_hf_group(data.maps, data.parameters, context.block_context, hf.passes, mut inputs, mut coefficients)!
		for pass, input in inputs {
			index := if combined { 0 } else { 2 + low.len + pass * int(frame.num_groups()) + int(group) }
			sections[index] = input.reader
			modular.read_group(mut sections[index], frame, false, group, pass, global.tree, storage)!
			if !combined { finish_modular_section(mut sections[index], index, false)! }
		}
		pixels := render_hf_group(data.maps, data.parameters, context.block_context, data.colors, data.lf,
			coefficients, hf.matrices, HfGroupRendering{ storage: hf.passes.coefficient_storage,
				quantizer: context.quantizer, x_qm_scale: frame.x_qm_scale, b_qm_scale: frame.b_qm_scale,
				color_correlation: context.color_correlation, biases: file.transform.opsin.quant_biases })!
		r := frame.block_group_rect(group)!
		for c in 0 .. 3 {
			for y in 0 .. pixels[c].height {
				for x in 0 .. pixels[c].width {
					samples[c][(int(r.y * 8 >> vs[c]) + y) * (w >> hs[c]) + int(r.x * 8 >> hs[c]) + x] = pixels[c].samples[y * pixels[c].width + x]
				}
			}
		}
	}
	if combined { finish_modular_section(mut sections[0], 0, false)! }
	mut planes := [3]FloatPlane{}
	for c in 0 .. 3 { planes[c] = FloatPlane{ width: w >> hs[c], height: h >> vs[c], samples: samples[c] } }
	return VarDctFramePlanes{ planes: planes,
		epf_maps: VarDctEpfMaps{ width: bw, height: bh, raw_quant: raw_quant, transform_ids: transforms, sharpness: sharpness },
		quantizer: context.quantizer, extra_channels: modular.reconstruct(storage)!, noise: global.noise,
		color_correlation: context.color_correlation, spline_cache: global.spline_cache, patches: global.patches }
}
