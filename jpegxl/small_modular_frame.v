// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct SmallModularFrame {
pub:
	quantization LfQuantFactors
	channels     []ModularChannel
}

fn frame_color_channels(file FileHeader, frame FrameHeader) int {
	return if !frame.do_ycbcr && !file.metadata.xyb_encoded && file.metadata.color_encoding.color_space == .gray {
		1
	} else {
		3
	}
}

fn small_modular_channel_info(file FileHeader, frame FrameHeader) ![]ModularChannelInfo {
	return modular_frame_channel_info(file, frame, frame_color_channels(file, frame))
}

fn modular_frame_channel_info(file FileHeader, frame FrameHeader, colors int) ![]ModularChannelInfo {
	if frame.upsampling == 0 || frame.extra_upsampling.len != file.metadata.extra_channels.len {
		return error('Invalid JPEG XL modular frame sampling metadata')
	}
	size := frame.size()
	mut infos := []ModularChannelInfo{}
	for c in 0 .. colors {
		h := frame.hshift(c)!
		v := frame.vshift(c)!
		infos << ModularChannelInfo{ width: int(frame_ceil_div(size.width, u32(1) << h)), height: int(frame_ceil_div(size.height, u32(1) << v)), shift: ModularShift{ horizontal: h, vertical: v }, bit_depth: file.metadata.bit_depth, output_channel: u32(c) }
	}
	upsampled := frame.size_upsampled()
	for i, factor in frame.extra_upsampling {
		if factor < frame.upsampling || factor == 0 || factor & (factor - 1) != 0 {
			return error('Invalid JPEG XL modular extra-channel sampling')
		}
		shift := u32(ceil_log2(int(factor)) - ceil_log2(int(frame.upsampling)))
		infos << ModularChannelInfo{ width: int(frame_ceil_div(upsampled.width, factor)), height: int(frame_ceil_div(upsampled.height, factor)), shift: ModularShift{ horizontal: shift, vertical: shift }, bit_depth: file.metadata.bit_depth, output_channel: u32(3 + i) }
	}
	return infos
}

struct ModularGlobalPlan {
	quantization LfQuantFactors
	tree         ?ModularTree
	header       ModularGroupHeader
	plan         ModularTransformPlan
}

fn (mut reader BitReader) read_modular_global_plan(file FileHeader, frame FrameHeader) !ModularGlobalPlan {
	if frame.encoding != .modular || frame.has_patches() || frame.has_noise() || frame.has_splines() {
		return error('JPEG XL frame requires unsupported global-section services')
	}
	infos := small_modular_channel_info(file, frame)!
	limits := modular_stream_limits(infos)!
	quantization := reader.read_lf_quant_factors()!
	mut global := ?ModularTree(none)
	if reader.read(1)! != 0 {
		samples := u64(frame.width) * u64(frame.height) * u64(infos.len) / 16 + 1024
		limit := if samples < 131070 { int(samples) } else { 131070 }
		global = reader.read_modular_tree(limit)!
	}
	header := reader.read_modular_group_header()!
	plan := plan_modular_transforms(infos, header, limits)!
	return ModularGlobalPlan{ quantization: quantization, tree: global, header: header, plan: plan }
}

// Decode all raw planes when every coded channel belongs to the global section.
// Color conversion, filters, orientation, later frames and grouped channels are separate.
pub fn (mut reader BitReader) decode_small_modular_frame(file FileHeader, frame FrameHeader, storage ModularStorage) !SmallModularFrame {
	global := reader.read_modular_global_plan(file, frame)!
	plan := global.plan
	for id in plan.coded {
		info := plan.buffers[id]
		if info.shift != none && (info.width > int(frame.group_dimension()) || info.height > int(frame.group_dimension())) {
			return error('JPEG XL modular frame requires grouped channel decoding')
		}
	}
	coded_info := plan.coded.map(plan.buffers[it].allocated())
	coded := reader.decode_modular_stream(coded_info, storage, 0, global.header, global.tree)!
	return SmallModularFrame{ quantization: global.quantization, channels: plan.reconstruct(coded, storage)! }
}
