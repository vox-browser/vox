// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_2d_byte_uploads_use_driver_bindings_and_driver_validation() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		texture := context.create_texture()
		C.vox_gl_bind_texture(texture_2d, texture.object.native_handle_)
		assert texture_2d !in context.bound_texture_objects
		pixels := [u8(255), 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 0, 255]
		other.native.make_current()
		context.tex_image2d(texture_2d, 0, rgba, 2, 2, 0, rgba, unsigned_byte, pixels)
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_error() == no_error
		image_framebuffer := context.create_framebuffer()
		context.bind_framebuffer(framebuffer, image_framebuffer)
		context.framebuffer_texture2d(framebuffer, color_attachment0, texture_2d, texture, 0)
		assert context.check_framebuffer_status(framebuffer) == 0x8cd5
		assert context.read_pixels(0, 0, 2, 2, rgba, unsigned_byte) == pixels
		other.native.make_current()
		context.tex_sub_image2d(texture_2d, 0, 1, 0, 1, 1, rgba, unsigned_byte, [
			u8(64),
			128,
			192,
			255,
		])
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_error() == no_error
		assert context.read_pixels(1, 0, 1, 1, rgba, unsigned_byte) == [u8(64), 128, 192, 255]
		C.vox_gl_tex_image2d(0xbad, 0, rgba, -1, 2, 1, rgba, unsigned_byte, pixels.len, pixels.data)
		expected_image_error := C.vox_gl_get_error()
		other.native.make_current()
		context.tex_image2d(0xbad, 0, rgba, -1, 2, 1, rgba, unsigned_byte, pixels)
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_error() == expected_image_error
		C.vox_gl_tex_sub_image2d(0xbad, 0, 0, 0, -1, 2, rgba, unsigned_byte, pixels.len, pixels.data)
		expected_sub_image_error := C.vox_gl_get_error()
		other.native.make_current()
		context.tex_sub_image2d(0xbad, 0, 0, 0, -1, 2, rgba, unsigned_byte, pixels)
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_error() == expected_sub_image_error
		if version == .webgl2 {
			context.pixel_storei(unpack_row_length, 1)
			other.native.make_current()
			context.tex_image2d(0xbad, 0, rgba, 2, 2, 0, rgba, unsigned_byte, pixels)
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			assert context.get_error() == invalid_operation
			other.native.make_current()
			context.tex_sub_image2d_null(0xbad, 0, 0, 0, 2, 2, rgba, unsigned_byte)
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			assert context.get_error() == invalid_operation
		} else {
			other.native.make_current()
			context.tex_image2d_null(0xbad, 0, int(rgba), 2, 2, 0, rgba, unsigned_short_5_6_5)
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			assert context.get_error() == invalid_operation
			other.native.make_current()
			context.tex_sub_image2d_null(0xbad, 0, 0, 0, 2, 2, rgba, unsigned_byte)
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			assert context.get_error() == invalid_value
		}
	}
}
