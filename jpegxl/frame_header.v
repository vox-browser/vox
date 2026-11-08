// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub enum FrameType {
	regular
	lf
	reference_only
	skip_progressive
}

pub enum FrameEncoding {
	vardct
	modular
}

pub enum BlendingMode {
	replace
	add
	blend
	alpha_weighted_add
	multiply
}

pub struct BlendingInfo {
pub:
	mode          BlendingMode = .replace
	alpha_channel u32
	clamp         bool
	source        u32
}

pub struct FrameHeaderContext {
pub:
	xyb_encoded    bool
	extra_channels []ExtraChannelInfo
	have_animation bool
	have_timecode  bool
	image_size     Size
}

pub struct FrameHeader {
pub mut:
	frame_type                  FrameType     = .regular
	encoding                    FrameEncoding = .vardct
	flags                       u64
	do_ycbcr                    bool
	jpeg_upsampling             [3]u32
	upsampling                  u32 = 1
	extra_upsampling            []u32
	group_size_shift            u32 = 1
	x_qm_scale                  u32 = 3
	b_qm_scale                  u32 = 2
	passes                      Passes
	lf_level                    u32
	have_crop                   bool
	x0                          i32
	y0                          i32
	crop_width                  u32
	crop_height                 u32
	full_frame                  bool = true
	blending                    BlendingInfo
	extra_blending              []BlendingInfo
	duration_ticks              u32
	timecode                    u32
	is_last                     bool = true
	save_as_reference           u32
	can_be_referenced           bool
	save_before_color_transform bool
	name                        string
	restoration                 RestorationFilter
	width                       u32
	height                      u32
	max_hshift                  u32
	max_vshift                  u32
}

pub fn (header FileHeader) frame_header_context() FrameHeaderContext {
	return header.frame_header_context_with_size(header.size)
}

pub fn (header FileHeader) preview_frame_header_context() ?FrameHeaderContext {
	size := header.metadata.preview or { return none }
	return header.frame_header_context_with_size(size)
}

fn (header FileHeader) frame_header_context_with_size(size Size) FrameHeaderContext {
	animation := header.metadata.animation
	return FrameHeaderContext{
		xyb_encoded:    header.metadata.xyb_encoded
		extra_channels: header.metadata.extra_channels
		have_animation: animation != none
		have_timecode:  if value := animation { value.have_timecodes } else { false }
		image_size:     size
	}
}

pub fn (mut reader BitReader) read_blending_info(extra_channels int, full_frame bool) !BlendingInfo {
	value := reader.read_u32([U32Code{}, U32Code{ offset: 1 }, U32Code{ offset: 2 },
		U32Code{ bits: 2, offset: 3 }]!)!
	if value > 4 { return error('Invalid JPEG XL blending mode') }
	uses_alpha := value == 2 || value == 3
	alpha := if extra_channels > 0 && uses_alpha {
		reader.read_u32([U32Code{}, U32Code{ offset: 1 }, U32Code{ offset: 2 },
			U32Code{ bits: 3, offset: 3 }]!)!
	} else {
		u32(0)
	}
	clamp := if (extra_channels > 0 && uses_alpha) || value == 4 {
		reader.read(1)! != 0
	} else {
		false
	}
	source := if !(full_frame && value == 0) { u32(reader.read(2)!) } else { u32(0) }
	return BlendingInfo{ mode: unsafe { BlendingMode(value) }, alpha_channel: alpha, clamp: clamp, source: source }
}

pub fn (mut reader BitReader) read_frame_header(context FrameHeaderContext) !FrameHeader {
	if context.extra_channels.len > 256 || context.image_size.width == 0 || context.image_size.height == 0 {
		return error('Invalid JPEG XL frame context')
	}
	reader.align_to_byte()!
	all_default := reader.read(1)! != 0
	mut frame := FrameHeader{
		restoration:      RestorationFilter.default()
		width:            context.image_size.width
		height:           context.image_size.height
		extra_upsampling: []u32{len: context.extra_channels.len, init: 1}
		extra_blending:   []BlendingInfo{len: context.extra_channels.len}
	}
	if !all_default {
		frame.frame_type = unsafe { FrameType(reader.read(2)!) }
		frame.encoding = unsafe { FrameEncoding(reader.read(1)!) }
		frame.flags = reader.read_u64()!
		if !context.xyb_encoded { frame.do_ycbcr = reader.read(1)! != 0 }
		if frame.do_ycbcr && !frame.has_lf_frame() {
			for i in 0 .. 3 { frame.jpeg_upsampling[i] = u32(reader.read(2)!) }
		}
		if !frame.has_lf_frame() {
			frame.upsampling = u32(1) << reader.read(2)!
			for i in 0 .. context.extra_channels.len {
				frame.extra_upsampling[i] = u32(1) << reader.read(2)!
			}
		}
		if frame.encoding == .modular { frame.group_size_shift = u32(reader.read(2)!) }
		if frame.encoding == .vardct && context.xyb_encoded {
			frame.x_qm_scale = u32(reader.read(3)!)
			frame.b_qm_scale = u32(reader.read(3)!)
		}
		if frame.frame_type != .reference_only { frame.passes = reader.read_passes()! }
		if frame.frame_type == .lf { frame.lf_level = u32(reader.read(2)! + 1) }
		if frame.frame_type != .lf { frame.have_crop = reader.read(1)! != 0 }
		crop_coder := [U32Code{ bits: 8 }, U32Code{ bits: 11, offset: 256 },
			U32Code{ bits: 14, offset: 2304 }, U32Code{ bits: 30, offset: 18688 }]!
		if frame.have_crop && frame.frame_type != .reference_only {
			frame.x0 = unpack_signed(reader.read_u32(crop_coder)!)
			frame.y0 = unpack_signed(reader.read_u32(crop_coder)!)
		}
		if frame.have_crop {
			frame.crop_width = reader.read_u32(crop_coder)!
			frame.crop_height = reader.read_u32(crop_coder)!
		}
		covers := frame.x0 <= 0 && frame.y0 <= 0 && i64(frame.crop_width) + i64(frame.x0) >= i64(context.image_size.width) && i64(frame.crop_height) + i64(frame.y0) >= i64(context.image_size.height)
		frame.full_frame = !frame.have_crop || covers
		if frame.frame_type == .regular || frame.frame_type == .skip_progressive {
			frame.blending = reader.read_blending_info(context.extra_channels.len, frame.full_frame)!
			for i in 0 .. context.extra_channels.len {
				frame.extra_blending[i] = reader.read_blending_info(context.extra_channels.len, frame.full_frame)!
			}
			if context.have_animation {
				frame.duration_ticks = reader.read_u32([U32Code{}, U32Code{ offset: 1 },
					U32Code{ bits: 8 }, U32Code{ bits: 32 }]!)!
			}
			if context.have_timecode { frame.timecode = u32(reader.read(32)!) }
			frame.is_last = reader.read(1)! != 0
		} else {
			frame.is_last = false
		}
		if frame.frame_type != .lf && !frame.is_last {
			frame.save_as_reference = u32(reader.read(2)!)
		}
		frame.can_be_referenced = !frame.is_last && frame.frame_type != .lf && (frame.duration_ticks == 0 || frame.save_as_reference != 0)
		save_condition := frame.can_be_referenced && frame.blending.mode == .replace && frame.full_frame && (frame.frame_type == .regular || frame.frame_type == .skip_progressive)
		frame.save_before_color_transform = if frame.frame_type == .reference_only || save_condition {
			reader.read(1)! != 0
		} else {
			frame.frame_type == .lf
		}
		frame.name = reader.read_name()!
		frame.restoration = reader.read_restoration_filter(frame.encoding)!
		reader.skip_extensions()!
		frame.width = if frame.crop_width == 0 {
			context.image_size.width
		} else {
			frame.crop_width
		}
		frame.height = if frame.crop_height == 0 {
			context.image_size.height
		} else {
			frame.crop_height
		}
		for selector in frame.jpeg_upsampling {
			if selector == 1 || selector == 2 { frame.max_hshift = 1 }
			if selector == 1 || selector == 3 { frame.max_vshift = 1 }
		}
	}
	frame.validate(context)!
	return frame
}

fn (frame FrameHeader) validate(context FrameHeaderContext) ! {
	if frame.upsampling > 1 {
		for i, info in context.extra_channels {
			effective := frame.extra_upsampling[i] << info.dimension_shift
			if effective < frame.upsampling || effective > 8 {
				return error('Invalid JPEG XL extra-channel upsampling')
			}
		}
	}
	if frame.has_patches() && frame.upsampling != 1 {
		for i, info in context.extra_channels {
			if (frame.extra_upsampling[i] << info.dimension_shift) != frame.upsampling {
				return error('Unsupported JPEG XL mixed patch upsampling')
			}
		}
	}
	if context.extra_channels.len > 0 {
		if (frame.blending.mode == .blend || frame.blending.mode == .alpha_weighted_add) && frame.blending.alpha_channel >= u32(context.extra_channels.len) {
			return error('Invalid JPEG XL blending alpha channel')
		}
		for blend in frame.extra_blending {
			if (blend.mode == .blend || blend.mode == .alpha_weighted_add) && blend.alpha_channel >= u32(context.extra_channels.len) {
				return error('Invalid JPEG XL extra blending alpha channel')
			}
		}
	}
	if frame.has_lf_frame() && frame.lf_level >= 4 { return error('Invalid JPEG XL LF level') }
	if frame.passes.downsample.len >= int(frame.passes.count) {
		return error('Invalid JPEG XL downsampling pass count')
	}
	for i in 1 .. frame.passes.downsample.len {
		if frame.passes.downsample[i] >= frame.passes.downsample[i - 1] {
			return error('Nondecreasing JPEG XL pass downsampling')
		}
	}
	for i in 1 .. frame.passes.last_pass.len {
		if frame.passes.last_pass[i] <= frame.passes.last_pass[i - 1] {
			return error('Nonincreasing JPEG XL last-pass order')
		}
	}
	for pass in frame.passes.last_pass {
		if pass >= frame.passes.count { return error('Invalid JPEG XL last-pass index') }
	}
	if !frame.save_before_color_transform && !frame.full_frame && frame.frame_type == .reference_only {
		return error('Invalid JPEG XL cropped reference frame')
	}
}

pub fn (mut frame FrameHeader) postprocess(context FrameHeaderContext) ! {
	if context.extra_channels.len != frame.extra_upsampling.len {
		return error('JPEG XL extra-channel context mismatch')
	}
	if frame.upsampling > 1 {
		for i, channel in context.extra_channels {
			frame.extra_upsampling[i] <<= channel.dimension_shift
		}
	}
	if frame.encoding != .vardct || !context.xyb_encoded { frame.x_qm_scale = 2 }
}
