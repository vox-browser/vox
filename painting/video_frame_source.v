// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

@[has_globals]
module painting

import dom

pub enum MediaVideoColorSpace {
	bt601
	bt709
}

pub enum MediaVideoSubsampling {
	yuv420
	yuv422
	yuv444
	monochrome
}

pub struct MediaVideoYUVData {
pub:
	y_plane     []u8
	u_plane     []u8
	v_plane     []u8
	a_plane     []u8
	y_stride    int
	u_stride    int
	v_stride    int
	a_stride    int
	subsampling MediaVideoSubsampling = .yuv420
	full_range  bool
	// Optional contiguous Y/U/V[/A] storage, retained for GPU plane uploads.
	packed_planes []u8
}

@[heap]
pub struct MediaVideoFrame {
pub:
	timestamp   f64
	duration    f64
	width       u32
	height      u32
	bit_depth   u8 = 8
	color_space MediaVideoColorSpace = .bt709
	decoded_color_space dom.DecodedImageColorSpace = .srgb
	yuv_data    ?MediaVideoYUVData
	rgba_bitmap ?&dom.Bitmap_
pub mut:
	// Advances whenever this frame's pixel storage is rewritten in place, so
	// retained-paint consumers can identify new pixels behind a reused object.
	generation u64
}

pub fn MediaVideoFrame.from_bitmap(bitmap &dom.Bitmap_) &MediaVideoFrame {
	return &MediaVideoFrame{
		width: u32(bitmap.width)
		height: u32(bitmap.height)
		rgba_bitmap: bitmap
	}
}

pub fn MediaVideoFrame.from_bitmap_with_color_space(bitmap &dom.Bitmap_, color_space dom.DecodedImageColorSpace) &MediaVideoFrame {
	return &MediaVideoFrame{
		width:               u32(bitmap.width)
		height:              u32(bitmap.height)
		decoded_color_space: color_space
		rgba_bitmap:         bitmap
	}
}

fn media_video_clamp_channel(value int) u8 {
	if value < 0 {
		return 0
	}
	if value > 255 {
		return 255
	}
	return u8(value)
}

// CPU conversion is the fallback used when the display-list backend cannot
// import the planar frame directly as a GPU image.
pub fn (frame &MediaVideoFrame) to_bitmap() !&dom.Bitmap_ {
	if bitmap := frame.rgba_bitmap {
		return bitmap
	}
	if frame.width == 0 || frame.height == 0 {
		return error('video frame has empty dimensions')
	}
	if frame.bit_depth != 8 {
		return error('unsupported video frame bit depth ${frame.bit_depth}')
	}
	yuv_data := frame.yuv_data or { return error('video frame has no decoded pixel data') }
	width := int(frame.width)
	height := int(frame.height)
	y_stride := if yuv_data.y_stride > 0 { yuv_data.y_stride } else { width }
	chroma_width := if yuv_data.subsampling in [.yuv420, .yuv422] {
		(width + 1) / 2
	} else {
		width
	}
	u_stride := if yuv_data.u_stride > 0 { yuv_data.u_stride } else { chroma_width }
	v_stride := if yuv_data.v_stride > 0 { yuv_data.v_stride } else { chroma_width }
	if yuv_data.y_plane.len < y_stride * height {
		return error('video frame luma plane is truncated')
	}
	chroma_height := if yuv_data.subsampling == .yuv420 {
		(height + 1) / 2
	} else {
		height
	}
	if yuv_data.subsampling != .monochrome
		&& (yuv_data.u_plane.len < u_stride * chroma_height
			|| yuv_data.v_plane.len < v_stride * chroma_height) {
		return error('video frame chroma plane is truncated')
	}
	a_stride := if yuv_data.a_stride > 0 { yuv_data.a_stride } else { width }
	if yuv_data.a_plane.len > 0 && yuv_data.a_plane.len < a_stride * height {
		return error('video frame alpha plane is truncated')
	}

	mut pixels := []u8{len: width * height * 4}
	for y in 0 .. height {
		for x in 0 .. width {
			y_value := int(yuv_data.y_plane[y * y_stride + x])
			chroma_x := if yuv_data.subsampling in [.yuv420, .yuv422] { x / 2 } else { x }
			chroma_y := if yuv_data.subsampling == .yuv420 { y / 2 } else { y }
			u_value := if yuv_data.subsampling == .monochrome {
				128
			} else {
				int(yuv_data.u_plane[chroma_y * u_stride + chroma_x])
			}
			v_value := if yuv_data.subsampling == .monochrome {
				128
			} else {
				int(yuv_data.v_plane[chroma_y * v_stride + chroma_x])
			}
			d := u_value - 128
			e := v_value - 128
			mut red := 0
			mut green := 0
			mut blue := 0
			if yuv_data.full_range {
				red_v_coefficient := if frame.color_space == .bt601 { 359 } else { 403 }
				green_u_coefficient := if frame.color_space == .bt601 { 88 } else { 48 }
				green_v_coefficient := if frame.color_space == .bt601 { 183 } else { 120 }
				blue_u_coefficient := if frame.color_space == .bt601 { 454 } else { 475 }
				red = y_value + (red_v_coefficient * e + 128) / 256
				green = y_value - (green_u_coefficient * d + green_v_coefficient * e + 128) / 256
				blue = y_value + (blue_u_coefficient * d + 128) / 256
			} else {
				c := if y_value > 16 { y_value - 16 } else { 0 }
				red_v_coefficient := if frame.color_space == .bt601 { 409 } else { 459 }
				green_u_coefficient := if frame.color_space == .bt601 { 100 } else { 55 }
				green_v_coefficient := if frame.color_space == .bt601 { 208 } else { 136 }
				blue_u_coefficient := if frame.color_space == .bt601 { 516 } else { 541 }
				red = (298 * c + red_v_coefficient * e + 128) / 256
				green = (298 * c - green_u_coefficient * d - green_v_coefficient * e + 128) / 256
				blue = (298 * c + blue_u_coefficient * d + 128) / 256
			}
			offset := (y * width + x) * 4
			pixels[offset] = media_video_clamp_channel(red)
			pixels[offset + 1] = media_video_clamp_channel(green)
			pixels[offset + 2] = media_video_clamp_channel(blue)
			pixels[offset + 3] = if yuv_data.a_plane.len > 0 {
				yuv_data.a_plane[y * a_stride + x]
			} else { 255 }
		}
	}
	return &dom.Bitmap_{
		width: width
		height: height
		pitch: width * 4
		data: pixels
	}
}

struct VideoFrameSourceIdentityAllocator {
mut:
	last u64
}

fn (mut allocator VideoFrameSourceIdentityAllocator) take() u64 {
	if allocator.last == u64(0xffffffffffffffff) { return 0 }
	allocator.last++
	return allocator.last
}

// Sources belong to the document's painting thread, like paint generations.
// A lifetime ID keeps recycled source/frame addresses out of texture identity.
__global video_frame_source_identities VideoFrameSourceIdentityAllocator

pub struct VideoFrameResourceIdentity {
pub:
	source     u64
	revision   u64
	generation u64
}

@[heap]
pub struct VideoFrameSource {
mut:
	frame_ ?&MediaVideoFrame
	resource_identity_ u64
	resource_revision_ u64
}

pub fn VideoFrameSource.create() &VideoFrameSource {
	return &VideoFrameSource{ resource_identity_: video_frame_source_identities.take() }
}

pub fn (mut source VideoFrameSource) update(frame ?&MediaVideoFrame) {
	mut replaced := true
	if previous := source.frame_ {
		if next := frame { replaced = voidptr(previous) != voidptr(next) }
	}
	if replaced {
		if source.resource_revision_ == u64(0xffffffffffffffff) {
			source.resource_identity_ = 0
		} else {
			source.resource_revision_++
		}
	}
	source.frame_ = frame
}

pub fn (mut source VideoFrameSource) clear() {
	source.frame_ = none
}

pub fn (source &VideoFrameSource) current_frame() ?&MediaVideoFrame {
	return source.frame_
}

pub fn (source &VideoFrameSource) resource_identity() VideoFrameResourceIdentity {
	frame := source.frame_ or { return VideoFrameResourceIdentity{} }
	if source.resource_identity_ == 0 || source.resource_revision_ == 0 {
		return VideoFrameResourceIdentity{}
	}
	return VideoFrameResourceIdentity{
		source:     source.resource_identity_
		revision:   source.resource_revision_
		generation: frame.generation
	}
}
