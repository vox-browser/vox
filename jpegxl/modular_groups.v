// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

fn validate_modular_group_geometry(frame FrameHeader) ! {
	if frame.width == 0 || frame.height == 0 || frame.group_size_shift > 3 || frame.lf_level > 4 || frame.upsampling !in [
		u32(1),
		2,
		4,
		8,
	] || frame.passes.count == 0 || frame.passes.count > 11 {
		return error('Invalid JPEG XL modular group geometry')
	}
}

// Input order is the coded-channel order, rather than transform buffer IDs.
// Buckets are global, LF groups, then one bucket per HF pass.
pub fn plan_modular_sections(input []ModularChannelInfo, frame FrameHeader) ![][]int {
	validate_modular_group_geometry(frame)!
	modular_stream_limits(input)!
	mut sections := [][]int{len: 2 + int(frame.passes.count)}
	mut prefix := 0
	for prefix < input.len {
		info := input[prefix]
		if info.shift != none && (info.width > int(frame.group_dimension()) || info.height > int(frame.group_dimension())) {
			break
		}
		sections[0] << prefix
		prefix++
	}
	for c in prefix .. input.len {
		shift := input[c].shift or { continue }
		minimum := int(if shift.horizontal < shift.vertical {
			shift.horizontal
		} else {
			shift.vertical
		})
		if minimum >= 3 { sections[1] << c }
		for p in 0 .. int(frame.passes.count) {
			low, high := frame.passes.downsampling_bracket(p)!
			if low <= minimum && minimum <= high { sections[2 + p] << c }
		}
	}
	return sections
}

pub struct ModularTile {
pub:
	x      int
	y      int
	width  int
	height int
}

pub fn modular_group_tile(info ModularChannelInfo, frame FrameHeader, lf bool, group u64) !ModularTile {
	validate_modular_group_geometry(frame)!
	modular_sample_count(info.width, info.height)!
	shift := info.shift or { return error('JPEG XL metadata channel cannot be grouped') }
	if shift.horizontal > 31 || shift.vertical > 31 {
		return error('Invalid JPEG XL channel shift')
	}
	grid := if lf { frame.size_lf_groups() } else { frame.size_groups() }
	if group >= u64(grid.width) * u64(grid.height) {
		return error('Invalid JPEG XL modular group index')
	}
	dimension := if lf { frame.lf_group_dimension() } else { frame.group_dimension() }
	tile_width := u64(dimension >> shift.horizontal)
	tile_height := u64(dimension >> shift.vertical)
	x := group % u64(grid.width) * tile_width
	y := group / u64(grid.width) * tile_height
	if x > u64(info.width) || y > u64(info.height) {
		return error('JPEG XL tile exceeds its channel')
	}
	width := if u64(info.width) - x < tile_width { u64(info.width) - x } else { tile_width }
	height := if u64(info.height) - y < tile_height { u64(info.height) - y } else { tile_height }
	return ModularTile{ x: int(x), y: int(y), width: if height == 0 { 0 } else { int(width) }, height: if width == 0 {
		0
	} else {
		int(height)
	} }
}

pub fn (frame FrameHeader) modular_lf_stream_id(group u64) !u32 {
	validate_modular_group_geometry(frame)!
	if group >= frame.num_lf_groups() { return error('Invalid JPEG XL LF stream index') }
	id := 1 + frame.num_lf_groups() + group
	if id > 4294967295 { return error('JPEG XL modular stream ID overflow') }
	return u32(id)
}

pub fn (frame FrameHeader) modular_hf_stream_id(pass int, group u64) !u32 {
	validate_modular_group_geometry(frame)!
	if pass < 0 || pass >= int(frame.passes.count) || group >= frame.num_groups() {
		return error('Invalid JPEG XL HF stream index')
	}
	// The source reserves seventeen VarDCT quant-table stream identities.
	id := 1 + frame.num_lf_groups() * 3 + 17 + frame.num_groups() * u64(pass) + group
	if id > 4294967295 { return error('JPEG XL modular stream ID overflow') }
	return u32(id)
}
