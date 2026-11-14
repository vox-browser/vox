// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn source_3d_upload_current_viewport() [4]i32 {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	return selected
}

fn test_source_3d_byte_uploads_delegate_actual_storage_and_competing_errors() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	texture := context.create_texture()
	C.vox_gl_bind_texture(texture_3d, texture.object.native_handle_)
	assert texture_3d !in context.bound_texture_objects
	pixels := [u8(255), 0, 0, 255, 0, 0, 255, 255]
	other.native.make_current()
	context.tex_image3d(texture_3d, 0, 0x8058, 1, 1, 2, 0, rgba, unsigned_byte, pixels)
	assert source_3d_upload_current_viewport() == [i32(1), 2, 3, 4]!
	assert context.get_error() == no_error
	image_framebuffer := context.create_framebuffer()
	context.bind_framebuffer(framebuffer, image_framebuffer)
	context.framebuffer_texture_layer(framebuffer, color_attachment0, texture, 0, 0)
	assert context.check_framebuffer_status(framebuffer) == 0x8cd5
	assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == pixels[..4]
	context.framebuffer_texture_layer(framebuffer, color_attachment0, texture, 0, 1)
	assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == pixels[4..]
	other.native.make_current()
	context.tex_sub_image3d(texture_3d, 0, 0, 0, 1, 1, 1, 1, rgba, unsigned_byte, [
		u8(64),
		128,
		192,
		255,
	])
	assert source_3d_upload_current_viewport() == [i32(1), 2, 3, 4]!
	assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == [u8(64), 128, 192, 255]
	assert context.get_error() == no_error
	C.vox_gl_tex_image3d(0xbad, 0, 0x8058, -1, 1, 1, 1, rgba, unsigned_byte, pixels.len, pixels.data)
	expected_image := C.vox_gl_get_error()
	other.native.make_current()
	context.tex_image3d(0xbad, 0, 0x8058, -1, 1, 1, 1, rgba, unsigned_byte, pixels)
	assert source_3d_upload_current_viewport() == [i32(1), 2, 3, 4]!
	assert context.get_error() == expected_image
	C.vox_gl_tex_sub_image3d(0xbad, 0, 0, 0, 0, -1, 1, 1, rgba, unsigned_byte, pixels.len, pixels.data)
	expected_sub_image := C.vox_gl_get_error()
	other.native.make_current()
	context.tex_sub_image3d(0xbad, 0, 0, 0, 0, -1, 1, 1, rgba, unsigned_byte, pixels)
	assert source_3d_upload_current_viewport() == [i32(1), 2, 3, 4]!
	assert context.get_error() == expected_sub_image
	C.vox_gl_tex_image3d(0xbad, 0, 0x8058, -1, 1, 1, 1, rgba, unsigned_byte, 0, unsafe { nil })
	expected_null_image := C.vox_gl_get_error()
	other.native.make_current()
	context.tex_image3d_null(0xbad, 0, 0x8058, -1, 1, 1, 1, rgba, unsigned_byte)
	assert source_3d_upload_current_viewport() == [i32(1), 2, 3, 4]!
	assert context.get_error() == expected_null_image
	C.vox_gl_tex_sub_image3d(0xbad, 0, 0, 0, 0, -1, 1, 1, rgba, unsigned_byte, 0, unsafe { nil })
	expected_null_sub_image := C.vox_gl_get_error()
	other.native.make_current()
	context.tex_sub_image3d_null(0xbad, 0, 0, 0, 0, -1, 1, 1, rgba, unsigned_byte)
	assert source_3d_upload_current_viewport() == [i32(1), 2, 3, 4]!
	assert context.get_error() == expected_null_sub_image
}
