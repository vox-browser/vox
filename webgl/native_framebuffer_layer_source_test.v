// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn framebuffer_layer_source_owner() {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == [i32(1), 2, 3, 4]!
}

fn test_source_framebuffer_texture_layer_selects_owner_before_only_handle_gate() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	texture := context.create_texture()
	foreign := other.create_texture()
	other.native.make_current()
	context.framebuffer_texture_layer(0xbad, 0xbad, foreign, -1, -1)
	framebuffer_layer_source_owner()
	assert C.vox_gl_get_error() == no_error
	assert context.get_error() == invalid_operation
	context.bind_texture(texture_2d_array, texture)
	context.tex_image3d(texture_2d_array, 0, 0x8058, 1, 1, 2, 0, rgba, unsigned_byte,
		[u8(1), 2, 3, 255, 4, 5, 6, 255])
	target := context.create_framebuffer()
	context.bind_framebuffer(framebuffer, target)
	other.native.make_current()
	context.framebuffer_texture_layer(framebuffer, color_attachment0, texture, 0, 1)
	framebuffer_layer_source_owner()
	assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == [u8(4), 5, 6, 255]
	assert target.attachment(color_attachment0) == none
	assert context.get_error() == no_error
	for arguments in [[i64(0xbad), i64(color_attachment0), i64(0), i64(0)],
		[i64(framebuffer), i64(0xbad), i64(0), i64(0)],
		[i64(framebuffer), i64(color_attachment0), i64(-1), i64(0)],
		[i64(framebuffer), i64(color_attachment0), i64(0), i64(-1)]] {
		C.vox_gl_framebuffer_texture_layer(GLenum(arguments[0]), GLenum(arguments[1]),
			texture.object.native_handle_, int(arguments[2]), int(arguments[3]))
		expected := C.vox_gl_get_error()
		assert expected != no_error
		other.native.make_current()
		context.framebuffer_texture_layer(GLenum(arguments[0]), GLenum(arguments[1]), texture,
			int(arguments[2]), int(arguments[3]))
		framebuffer_layer_source_owner()
		assert context.get_error() == expected
	}
	other.native.make_current()
	context.framebuffer_texture_layer(framebuffer, color_attachment0, none, 0, 0)
	framebuffer_layer_source_owner()
	assert context.check_framebuffer_status(framebuffer) == 0x8cd7
	assert context.get_error() == no_error
	context.delete_texture(texture)
	other.native.make_current()
	context.framebuffer_texture_layer(0xbad, 0xbad, texture, -1, -1)
	framebuffer_layer_source_owner()
	assert context.get_error() == invalid_operation
}
