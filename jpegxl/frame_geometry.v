// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

fn frame_ceil_div(value u32, divisor u32) u32 {
	return value / divisor + if value % divisor != 0 { u32(1) } else { u32(0) }
}

pub fn (frame FrameHeader) log_group_dimension() u32 { return 7 + frame.group_size_shift }

pub fn (frame FrameHeader) group_dimension() u32 { return u32(1) << frame.log_group_dimension() }

pub fn (frame FrameHeader) lf_group_dimension() u32 { return frame.group_dimension() * 8 }

pub fn (frame FrameHeader) has_noise() bool { return frame.flags & 1 != 0 }

pub fn (frame FrameHeader) has_patches() bool { return frame.flags & 2 != 0 }

pub fn (frame FrameHeader) has_splines() bool { return frame.flags & 0x10 != 0 }

pub fn (frame FrameHeader) has_lf_frame() bool { return frame.flags & 0x20 != 0 }

pub fn (frame FrameHeader) should_do_adaptive_lf_smoothing() bool {
	return frame.flags & 0x80 == 0 && !frame.has_lf_frame() && frame.encoding == .vardct
}

pub fn (frame FrameHeader) is_visible() bool {
	return (frame.is_last || frame.duration_ticks > 0) && (frame.frame_type == .regular || frame.frame_type == .skip_progressive)
}

pub fn (frame FrameHeader) duration_milliseconds(animation Animation) f64 {
	return f64(frame.duration_ticks) * 1000.0 * f64(animation.ticks_denominator) / f64(animation.ticks_numerator)
}

pub fn (frame FrameHeader) needs_blending() bool {
	if frame.frame_type != .regular && frame.frame_type != .skip_progressive { return false }
	return frame.have_crop || frame.blending.mode != .replace || frame.extra_blending.any(it.mode != .replace)
}

pub fn (frame FrameHeader) hshift(channel int) !u32 {
	if channel < 0 || channel >= 3 || frame.jpeg_upsampling[channel] > 3 {
		return error('Invalid JPEG XL sampling channel')
	}
	raw := if frame.jpeg_upsampling[channel] == 1 || frame.jpeg_upsampling[channel] == 2 {
		u32(1)
	} else {
		u32(0)
	}
	if raw > frame.max_hshift { return error('Invalid JPEG XL horizontal sampling shift') }
	return frame.max_hshift - raw
}

pub fn (frame FrameHeader) vshift(channel int) !u32 {
	if channel < 0 || channel >= 3 || frame.jpeg_upsampling[channel] > 3 {
		return error('Invalid JPEG XL sampling channel')
	}
	raw := if frame.jpeg_upsampling[channel] == 1 || frame.jpeg_upsampling[channel] == 3 {
		u32(1)
	} else {
		u32(0)
	}
	if raw > frame.max_vshift { return error('Invalid JPEG XL vertical sampling shift') }
	return frame.max_vshift - raw
}

fn (frame FrameHeader) matches_sampling(horizontal [3]u32, vertical [3]u32) bool {
	for c in 0 .. 3 {
		h := frame.hshift(c) or { return false }
		v := frame.vshift(c) or { return false }
		if h != horizontal[c] || v != vertical[c] { return false }
	}
	return true
}

pub fn (frame FrameHeader) is444() bool {
	return frame.matches_sampling([u32(0), 0, 0]!, [u32(0), 0, 0]!)
}

pub fn (frame FrameHeader) is420() bool {
	return frame.matches_sampling([u32(1), 0, 1]!, [u32(1), 0, 1]!)
}

pub fn (frame FrameHeader) is422() bool {
	return frame.matches_sampling([u32(1), 0, 1]!, [u32(0), 0, 0]!)
}

pub fn (frame FrameHeader) is440() bool {
	return frame.matches_sampling([u32(0), 0, 0]!, [u32(1), 0, 1]!)
}

pub fn (frame FrameHeader) size_upsampled() Size {
	scale := u32(1) << (3 * frame.lf_level)
	return Size{ width: frame_ceil_div(frame.width, scale), height: frame_ceil_div(frame.height, scale) }
}

pub fn (frame FrameHeader) size() Size {
	upsampled := frame.size_upsampled()
	return Size{ width: frame_ceil_div(upsampled.width, frame.upsampling), height: frame_ceil_div(upsampled.height, frame.upsampling) }
}

pub fn (frame FrameHeader) size_blocks() Size {
	size := frame.size()
	return Size{
		width:  frame_ceil_div(size.width, u32(8) << frame.max_hshift) << frame.max_hshift
		height: frame_ceil_div(size.height, u32(8) << frame.max_vshift) << frame.max_vshift
	}
}

pub fn (frame FrameHeader) size_padded() Size {
	if frame.encoding == .modular { return frame.size() }
	blocks := frame.size_blocks()
	return Size{ width: blocks.width * 8, height: blocks.height * 8 }
}

pub fn (frame FrameHeader) size_padded_upsampled() Size {
	size := frame.size_padded()
	return Size{ width: size.width * frame.upsampling, height: size.height * frame.upsampling }
}

pub fn (frame FrameHeader) size_groups() Size {
	size := frame.size()
	return Size{ width: frame_ceil_div(size.width, frame.group_dimension()), height: frame_ceil_div(size.height, frame.group_dimension()) }
}

pub fn (frame FrameHeader) size_lf_groups() Size {
	size := frame.size_blocks()
	return Size{ width: frame_ceil_div(size.width, frame.group_dimension()), height: frame_ceil_div(size.height, frame.group_dimension()) }
}

pub fn (frame FrameHeader) num_groups() u64 {
	size := frame.size_groups()
	return u64(size.width) * u64(size.height)
}

pub fn (frame FrameHeader) num_lf_groups() u64 {
	size := frame.size_lf_groups()
	return u64(size.width) * u64(size.height)
}

pub fn (frame FrameHeader) num_toc_entries() u64 {
	groups := frame.num_groups()
	if groups == 1 && frame.passes.count == 1 { return 1 }
	return 2 + frame.num_lf_groups() + groups * u64(frame.passes.count)
}

fn frame_grid_rect(group u64, grid Size, extent Size, tile u32) !ImageRect {
	if grid.width == 0 || grid.height == 0 || group >= u64(grid.width) * u64(grid.height) {
		return error('Invalid JPEG XL group index')
	}
	x := u32(group % u64(grid.width)) * tile
	y := u32(group / u64(grid.width)) * tile
	if x > extent.width || y > extent.height { return error('JPEG XL group exceeds its extent') }
	return ImageRect{ x: x, y: y, width: math.min(extent.width - x, tile), height: math.min(extent.height - y, tile) }
}

pub fn (frame FrameHeader) group_rect(group u64) !ImageRect {
	return frame_grid_rect(group, frame.size_groups(), frame.size(), frame.group_dimension())
}

pub fn (frame FrameHeader) block_group_rect(group u64) !ImageRect {
	return frame_grid_rect(group, frame.size_groups(), frame.size_blocks(), frame.group_dimension() >> 3)
}

pub fn (frame FrameHeader) lf_group_rect(group u64) !ImageRect {
	return frame_grid_rect(group, frame.size_lf_groups(), frame.size_blocks(), frame.group_dimension())
}
