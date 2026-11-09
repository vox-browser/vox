// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct VarDctGroupData {
pub:
	maps       HfGroupMaps
	colors     HfGroupColorMap
	lf         [3]FloatPlane
	parameters HfGroupParameters
	sharpness  []u8
}

pub fn (frame FrameHeader) vardct_lf_group_for_group(group u64) !u64 {
	checked_vardct_lf_rect(frame, 0)!
	r := frame.block_group_rect(group)!
	return u64(r.y / frame.group_dimension()) * u64(frame.size_lf_groups().width)
		+ u64(r.x / frame.group_dimension())
}

fn crop_float_plane(input FloatPlane, x int, y int, width int, height int) !FloatPlane {
	input.validate()!
	if x < 0 || y < 0 || width < 0 || height < 0 || x > input.width || y > input.height
		|| width > input.width - x || height > input.height - y {
		return error('JPEG XL plane crop exceeds its source')
	}
	mut samples := []f32{len: width * height}
	for iy in 0 .. height {
		for ix in 0 .. width { samples[iy * width + ix] = input.samples[(y + iy) * input.width + x + ix] }
	}
	return FloatPlane{ width: width, height: height, samples: samples }
}

// Select one HF group from its owning LF group's decoded metadata and LF planes.
// Explicit ownership prevents silently combining same-sized unrelated LF groups.
pub fn select_vardct_group(frame FrameHeader, group u64, lf_group u64, metadata HfMetadata, lf VarDctLfResult) !VarDctGroupData {
	if frame.vardct_lf_group_for_group(group)! != lf_group { return error('Incorrect JPEG XL LF group owner') }
	area := frame.lf_group_rect(lf_group)!
	r := frame.block_group_rect(group)!
	if metadata.width != int(area.width) || metadata.height != int(area.height)
		|| lf.width != metadata.width || lf.height != metadata.height || lf.planes.len != 3 {
		return error('Invalid JPEG XL LF group storage geometry')
	}
	count := metadata.width * metadata.height
	cw := (metadata.width + 7) / 8
	ch := (metadata.height + 7) / 8
	if metadata.raw_quant.len != count || metadata.transform_ids.len != count
		|| metadata.sharpness.len != count || lf.quant_lf_contexts.len != count
		|| metadata.colors.y_to_x.len != cw * ch || metadata.colors.y_to_b.len != cw * ch {
		return error('Invalid JPEG XL LF group map storage')
	}
	x := int(r.x - area.x)
	y := int(r.y - area.y)
	w := int(r.width)
	h := int(r.height)
	mut raw := []i32{len: w * h}
	mut ids := []u8{len: w * h}
	mut contexts := []u8{len: w * h}
	mut sharpness := []u8{len: w * h}
	for iy in 0 .. h {
		for ix in 0 .. w {
			p := (y + iy) * metadata.width + x + ix
			q := iy * w + ix
			raw[q] = metadata.raw_quant[p]
			ids[q] = metadata.transform_ids[p]
			contexts[q] = lf.quant_lf_contexts[p]
			sharpness[q] = metadata.sharpness[p]
		}
	}
	color_width := (w + 7) / 8
	color_height := (h + 7) / 8
	mut color_x := []i32{len: color_width * color_height}
	mut color_b := []i32{len: color_width * color_height}
	for iy in 0 .. color_height {
		for ix in 0 .. color_width {
			p := (y / 8 + iy) * cw + x / 8 + ix
			color_x[iy * color_width + ix] = metadata.colors.y_to_x[p]
			color_b[iy * color_width + ix] = metadata.colors.y_to_b[p]
		}
	}
	mut hs := [3]u32{}
	mut vs := [3]u32{}
	mut planes := [3]FloatPlane{}
	for c in 0 .. 3 {
		hs[c] = frame.hshift(c)!
		vs[c] = frame.vshift(c)!
		if lf.planes[c].width != metadata.width >> hs[c] || lf.planes[c].height != metadata.height >> vs[c] {
			return error('Invalid JPEG XL subsampled LF plane geometry')
		}
		planes[c] = crop_float_plane(lf.planes[c], x >> hs[c], y >> vs[c], w >> hs[c], h >> vs[c])!
	}
	return VarDctGroupData{
		maps: HfGroupMaps{ width: w, height: h, raw_quant: raw, transform_ids: ids, lf_contexts: contexts }
		colors: HfGroupColorMap{ y_to_x: color_x, y_to_b: color_b }
		lf: planes
		parameters: HfGroupParameters{ horizontal_shift: hs, vertical_shift: vs, frame_passes: frame.passes }
		sharpness: sharpness
	}
}
