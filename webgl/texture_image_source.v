// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebGLRenderingContextBase::read_texture_image_source. The
// DOM element variants are normalized to the frame state visible at upload.
module webgl

import cpuraster

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
		frame:             WebGLBitmap{
			width:       frame.width
			height:      frame.height
			pitch:       frame.pitch
			layout:      frame.layout
			alpha_type:  frame.alpha_type
			color_space: frame.color_space
			pixels:      frame.pixels.clone()
		}
		flip_y:            context.unpack_flip_y_ && source.kind != .image_bitmap
		premultiply_alpha: context.unpack_premultiply_alpha_
	}
}

// Services/Compositor/HostWebGLContext.cpp::convert_bitmap_for_upload. The
// original frame metadata travels with the bitmap; cpuraster reproduces
// Skia's conversion beside GL, using the same Gfx export format and
// destination-size rules.
fn convert_bitmap_for_upload(source TexImageSourceFrame, format GLenum, type_ GLenum, destination_size ?WebGLIntSize) !cpuraster.BitmapExport {
	export_format := texture_export_format(format, type_) or { return error('Unsupported texture bitmap export format') }
	native_format := match export_format {
		.rgb888 { cpuraster.BitmapExportFormat.rgb888 }
		.rgb565 { cpuraster.BitmapExportFormat.rgb565 }
		.rgba8888 { cpuraster.BitmapExportFormat.rgba8888 }
		.rgba4444 { cpuraster.BitmapExportFormat.rgba4444 }
		.rgba5551 { cpuraster.BitmapExportFormat.rgba5551 }
		.alpha8 { cpuraster.BitmapExportFormat.alpha8 }
		.gray8 { cpuraster.BitmapExportFormat.gray8 }
	}
	mut width := ?int(none)
	mut height := ?int(none)
	if size := destination_size {
		width = size.width
		height = size.height
	}
	return cpuraster.export_bitmap_to_byte_buffer(cpuraster.BitmapSource{
		width:       source.frame.width
		height:      source.frame.height
		pitch:       source.frame.pitch
		layout:      source.frame.layout
		alpha_type:  source.frame.alpha_type
		color_space: source.frame.color_space
		pixels:      source.frame.pixels
	}, native_format, source.flip_y, source.premultiply_alpha, width, height)
}

// WebGLRenderingContextOverloads and WebGL2RenderingContextOverloads bitmap
// variants, followed by HostWebGLContext's robust native upload operation.
pub fn (mut context WebGLRenderingContext) tex_image2d_source(target GLenum, level int, internal_format int, format GLenum, type_ GLenum, source WebGLTextureImageSource, destination_size ?WebGLIntSize, border int) ! {
	context.native.make_current()
	if border != 0 {
		context.set_error(invalid_value)
		return
	}
	frame := context.read_texture_image_source(source, format, type_) or { return }
	converted := convert_bitmap_for_upload(frame, format, type_, destination_size)!
	context.command('tex_image2d_from_bitmap', target, level, internal_format, converted.width, converted.height, format, type_)
	C.vox_gl_tex_image2d(target, level, internal_format, converted.width, converted.height, 0, format, type_, converted.pixels.len, converted.pixels.data)
}

pub fn (mut context WebGLRenderingContext) tex_sub_image2d_source(target GLenum, level int, x_offset int, y_offset int, format GLenum, type_ GLenum, source WebGLTextureImageSource, destination_size ?WebGLIntSize) ! {
	context.native.make_current()
	frame := context.read_texture_image_source(source, format, type_) or { return }
	converted := convert_bitmap_for_upload(frame, format, type_, destination_size)!
	context.command('tex_sub_image2d_from_bitmap', target, level, x_offset, y_offset, converted.width, converted.height, format, type_)
	C.vox_gl_tex_sub_image2d(target, level, x_offset, y_offset, converted.width, converted.height, format, type_, converted.pixels.len, converted.pixels.data)
}

pub fn (mut context WebGLRenderingContext) tex_image3d_source(target GLenum, level int, internal_format int, depth int, format GLenum, type_ GLenum, source WebGLTextureImageSource, destination_size WebGLIntSize, border int) ! {
	context.native.make_current()
	if !context.require_webgl2() { return }
	if border != 0 {
		context.set_error(invalid_value)
		return
	}
	frame := context.read_texture_image_source(source, format, type_) or { return }
	converted := convert_bitmap_for_upload(frame, format, type_, destination_size)!
	context.command('tex_image3d_from_bitmap', target, level, internal_format, converted.width, converted.height, depth, format, type_)
	C.vox_gl_tex_image3d(target, level, internal_format, converted.width, converted.height, depth, 0, format, type_, converted.pixels.len, converted.pixels.data)
}

pub fn (mut context WebGLRenderingContext) tex_sub_image3d_source(target GLenum, level int, x_offset int, y_offset int, z_offset int, depth int, format GLenum, type_ GLenum, source WebGLTextureImageSource, destination_size WebGLIntSize) ! {
	context.native.make_current()
	if !context.require_webgl2() { return }
	frame := context.read_texture_image_source(source, format, type_) or { return }
	converted := convert_bitmap_for_upload(frame, format, type_, destination_size)!
	context.command('tex_sub_image3d_from_bitmap', target, level, x_offset, y_offset, z_offset, converted.width, converted.height, depth, format, type_)
	C.vox_gl_tex_sub_image3d(target, level, x_offset, y_offset, z_offset, converted.width, converted.height, depth, format, type_, converted.pixels.len, converted.pixels.data)
}
