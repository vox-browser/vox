// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn texture_storage_current_viewport() [4]i32 {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	return selected
}

fn test_source_texture_storage_uses_actual_bindings_and_driver_validation() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	texture := context.create_texture()
	C.vox_gl_bind_texture(texture_2d, texture.object.native_handle_)
	assert texture_2d !in context.bound_texture_objects
	other.native.make_current()
	context.tex_storage2d(texture_2d, 1, 0x8058, 2, 2)
	assert texture_storage_current_viewport() == [i32(1), 2, 3, 4]!
	assert context.get_tex_parameter(texture_2d, 0x912f).boolean
	assert context.get_tex_parameter(texture_2d, 0x82df).integer == 1
	assert context.get_error() == no_error
	volume := context.create_texture()
	C.vox_gl_bind_texture(texture_3d, volume.object.native_handle_)
	assert texture_3d !in context.bound_texture_objects
	other.native.make_current()
	context.tex_storage3d(texture_3d, 1, 0x8058, 1, 1, 2)
	assert texture_storage_current_viewport() == [i32(1), 2, 3, 4]!
	assert context.get_tex_parameter(texture_3d, 0x912f).boolean
	assert context.get_tex_parameter(texture_3d, 0x82df).integer == 1
	assert context.get_error() == no_error
	context.tex_sub_image3d(texture_3d, 0, 0, 0, 1, 1, 1, 1, rgba, unsigned_byte, [
		u8(64),
		128,
		192,
		255,
	])
	image_framebuffer := context.create_framebuffer()
	context.bind_framebuffer(framebuffer, image_framebuffer)
	context.framebuffer_texture_layer(framebuffer, color_attachment0, volume, 0, 1)
	assert context.check_framebuffer_status(framebuffer) == 0x8cd5
	assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == [u8(64), 128, 192, 255]
	assert context.get_error() == no_error
	C.vox_gl_tex_storage2d(0xbad, 0, 0x8058, -1, 0)
	expected_2d := C.vox_gl_get_error()
	other.native.make_current()
	context.tex_storage2d(0xbad, 0, 0x8058, -1, 0)
	assert texture_storage_current_viewport() == [i32(1), 2, 3, 4]!
	assert context.get_error() == expected_2d
	C.vox_gl_tex_storage3d(0xbad, 0, 0x8058, -1, 0, -1)
	expected_3d := C.vox_gl_get_error()
	other.native.make_current()
	context.tex_storage3d(0xbad, 0, 0x8058, -1, 0, -1)
	assert texture_storage_current_viewport() == [i32(1), 2, 3, 4]!
	assert context.get_error() == expected_3d
}
