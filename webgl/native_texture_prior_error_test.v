// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn texture_prior_error(mut context WebGLRenderingContext) {
	context.native.make_current()
	C.vox_gl_enable(0xbad)
}

fn texture_prior_error_was_retained(mut context WebGLRenderingContext) {
	assert context.get_error() == invalid_enum
	assert context.get_error() == no_error
}

fn test_source_bitmap_commands_upload_despite_an_earlier_driver_error() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		texture := context.create_texture()
		context.bind_texture(texture_2d, texture)
		fbo := context.create_framebuffer()
		context.bind_framebuffer(framebuffer, fbo)
		red_source := WebGLTextureImageSource{
			kind:  .image_data
			frame: WebGLBitmap{
				width:  1
				height: 1
				pixels: [u8(255), 0, 0, 255]
			}
		}
		blue := WebGLTextureImageSource{
			kind:  .image_bitmap
			frame: WebGLBitmap{
				width:  1
				height: 1
				pixels: [u8(0), 0, 255, 255]
			}
		}
		texture_prior_error(mut context)
		context.tex_image2d_source(texture_2d, 0, int(rgba), rgba, unsigned_byte, red_source, none, 0)!
		texture_prior_error_was_retained(mut context)
		context.framebuffer_texture2d(framebuffer, color_attachment0, texture_2d, texture, 0)
		assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == [u8(255), 0, 0, 255]
		texture_prior_error(mut context)
		context.tex_sub_image2d_source(texture_2d, 0, 0, 0, rgba, unsigned_byte, blue, none)!
		texture_prior_error_was_retained(mut context)
		assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == [u8(0), 0, 255, 255]
		if version == .webgl2 {
			array_texture := context.create_texture()
			context.bind_texture(texture_2d_array, array_texture)
			size := WebGLIntSize{ width: 1, height: 1 }
			texture_prior_error(mut context)
			context.tex_image3d_source(texture_2d_array, 0, 0x8058, 1, rgba, unsigned_byte, red_source, size, 0)!
			texture_prior_error_was_retained(mut context)
			context.framebuffer_texture_layer(framebuffer, color_attachment0, array_texture, 0, 0)
			assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == [u8(255), 0, 0, 255]
			texture_prior_error(mut context)
			context.tex_sub_image3d_source(texture_2d_array, 0, 0, 0, 0, 1, rgba, unsigned_byte, blue, size)!
			texture_prior_error_was_retained(mut context)
			assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == [u8(0), 0, 255, 255]
		}
		assert context.get_error() == no_error
	}
}

fn test_source_nullable_commands_upload_despite_an_earlier_driver_error() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		texture := context.create_texture()
		context.bind_texture(texture_2d, texture)
		context.tex_image2d(texture_2d, 0, rgba, 1, 1, 0, rgba, unsigned_byte, [
			u8(255),
			0,
			0,
			255,
		])
		fbo := context.create_framebuffer()
		context.bind_framebuffer(framebuffer, fbo)
		context.framebuffer_texture2d(framebuffer, color_attachment0, texture_2d, texture, 0)
		assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == [u8(255), 0, 0, 255]
		texture_prior_error(mut context)
		context.tex_image2d_null(texture_2d, 0, int(rgba), 1, 1, 0, rgba, unsigned_byte)
		texture_prior_error_was_retained(mut context)
		assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == [u8(0), 0, 0, 0]
		if version == .webgl2 {
			// The real unpack buffer makes nullptr an actual byte offset of zero.
			buffer := context.create_buffer()
			context.bind_buffer(pixel_unpack_buffer, buffer)
			context.buffer_data(pixel_unpack_buffer, [u8(0), 255, 0, 255], GLenum(0x88e4))
			texture_prior_error(mut context)
			context.tex_sub_image2d_null(texture_2d, 0, 0, 0, 1, 1, rgba, unsigned_byte)
			texture_prior_error_was_retained(mut context)
			assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == [u8(0), 255, 0, 255]
			array_texture := context.create_texture()
			context.bind_texture(texture_2d_array, array_texture)
			texture_prior_error(mut context)
			context.tex_image3d_null(texture_2d_array, 0, 0x8058, 1, 1, 1, 0, rgba, unsigned_byte)
			texture_prior_error_was_retained(mut context)
			context.framebuffer_texture_layer(framebuffer, color_attachment0, array_texture, 0, 0)
			assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == [u8(0), 255, 0, 255]
			context.buffer_data(pixel_unpack_buffer, [u8(0), 0, 255, 255], GLenum(0x88e4))
			texture_prior_error(mut context)
			context.tex_sub_image3d_null(texture_2d_array, 0, 0, 0, 0, 1, 1, 1, rgba, unsigned_byte)
			texture_prior_error_was_retained(mut context)
			assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == [u8(0), 0, 255, 255]
		}
		assert context.get_error() == no_error
	}
}
