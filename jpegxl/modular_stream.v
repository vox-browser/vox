// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

fn modular_stream_limits(input []ModularChannelInfo) !ModularPlanLimits {
	if input.len > 65536 { return error('Too many JPEG XL modular stream channels') }
	mut maximum := 1
	mut samples := u64(0)
	for info in input {
		samples += u64(modular_sample_count(info.width, info.height)!)
		if samples > 67108864 { return error('JPEG XL modular stream sample limit exceeded') }
		if info.width != 0 && info.height != 0 {
			if info.width > maximum { maximum = info.width }
			if info.height > maximum { maximum = info.height }
		}
	}
	depth := 2 + 2 * ceil_log2(maximum)
	count := input.len * depth + 64
	return ModularPlanLimits{ max_channels: if count < 65536 { count } else { 65536 } }
}

// A provided header belongs to buffers whose transforms are already planned
// (the global section). Otherwise read the header and plan its local transforms.
// This entry point consumes a complete stream; partial recovery is separate.
pub fn (mut reader BitReader) decode_modular_stream(input []ModularChannelInfo, storage ModularStorage, stream_id u32, provided_header ?ModularGroupHeader, global_tree ?ModularTree) ![]ModularChannel {
	limits := modular_stream_limits(input)!
	infos := input.map(ModularChannelInfo{ ...it.allocated(), output_channel: none, followed_by_palette: false })
	if infos.all(it.width == 0 || it.height == 0) {
		plan := plan_modular_transforms(infos, ModularGroupHeader{}, limits)!
		return plan.allocate_coded_channels()
	}
	header := provided_header or { reader.read_modular_group_header()! }
	transform_header := if provided_header != none { ModularGroupHeader{} } else { header }
	plan := plan_modular_transforms(infos, transform_header, limits)!
	mut coded := plan.allocate_coded_channels()!
	if header.use_global_tree && global_tree == none {
		return error('JPEG XL modular stream requires a global tree')
	}
	tree := if header.use_global_tree {
		global_tree or { return error('Missing JPEG XL global tree') }
	} else {
		mut samples := 0
		for channel in coded { samples += channel.samples.len }
		// The V entropy map supports at most 65,536 leaf contexts.
		limit := if samples + 1024 < 131070 { samples + 1024 } else { 131070 }
		reader.read_modular_tree(limit)!
	}
	reader.decode_modular_channels(mut coded, stream_id, header.weighted, tree, storage)!
	return plan.reconstruct(coded, storage)
}
