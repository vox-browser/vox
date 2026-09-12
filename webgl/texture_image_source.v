// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebGLRenderingContextBase::read_texture_image_source. The
// DOM element variants are normalized to the frame state visible at upload.
module webgl

pub enum WebGLTextureImageSourceKind {
	image_bitmap
	image_data
	image_element
	canvas
	offscreen_canvas
	video
}

pub struct WebGLTextureImageSource {
pub:
	kind               WebGLTextureImageSourceKind
	frame              ?WebGLBitmap
	data_detached      bool
	data_out_of_bounds bool
	bitmap_error       bool
}

pub struct TexImageSourceFrame {
pub:
	frame             WebGLBitmap
	flip_y            bool
	premultiply_alpha bool
}

pub fn (mut context WebGLRenderingContext) read_texture_image_source(source WebGLTextureImageSource, format GLenum, type_ GLenum) ?TexImageSourceFrame {
	if source.kind == .image_data
		&& (source.data_detached || source.data_out_of_bounds || source.bitmap_error) {
		context.set_error(invalid_value)
		return none
	}
	frame := source.frame or { return none }
	if texture_export_format(format, type_) == none {
		return none
	}
	return TexImageSourceFrame{
		frame: WebGLBitmap{
			width: frame.width
			height: frame.height
			pixels: frame.pixels.clone()
		}
		flip_y: context.unpack_flip_y_ && source.kind != .image_bitmap
		premultiply_alpha: context.unpack_premultiply_alpha_
	}
}
