// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn framebuffer_source_native_int(pname GLenum) int {
	mut result := i32(0)
	C.vox_gl_int_parameter(pname, &result)
	return result
}

fn test_source_framebuffer_renderbuffer_binds_write_slots_after_driver_errors() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		original := context.create_framebuffer()
		replacement := context.create_framebuffer()
		original_renderbuffer := context.create_renderbuffer()
		replacement_renderbuffer := context.create_renderbuffer()
		context.bind_framebuffer(framebuffer, original)
		context.bind_framebuffer(0xbad, replacement)
		assert context.get_parameter(framebuffer_binding).framebuffer? == replacement
		assert framebuffer_source_native_int(framebuffer_binding) == int(original.object.native_handle_)
		assert context.get_error() == invalid_enum
		context.bind_renderbuffer(renderbuffer, original_renderbuffer)
		context.bind_renderbuffer(0xbad, replacement_renderbuffer)
		assert context.get_parameter(renderbuffer_binding).renderbuffer? == replacement_renderbuffer
		assert framebuffer_source_native_int(renderbuffer_binding) == int(original_renderbuffer.object.native_handle_)
		assert context.get_error() == invalid_enum
		context.bind_framebuffer(0xbad, none)
		assert context.get_parameter(framebuffer_binding).kind == .none
		assert framebuffer_source_native_int(framebuffer_binding) == int(original.object.native_handle_)
		assert context.get_error() == invalid_enum
		context.bind_renderbuffer(0xbad, none)
		assert context.get_parameter(renderbuffer_binding).kind == .none
		assert framebuffer_source_native_int(renderbuffer_binding) == int(original_renderbuffer.object.native_handle_)
		assert context.get_error() == invalid_enum
		foreign := other.create_framebuffer()
		context.bind_framebuffer(0xbad, foreign)
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_error() == invalid_operation
		foreign_renderbuffer := other.create_renderbuffer()
		context.bind_renderbuffer(0xbad, foreign_renderbuffer)
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_error() == invalid_operation
		C.vox_gl_bind_buffer(0xbad, 0)
		context.bind_framebuffer(framebuffer, replacement)
		assert context.get_parameter(framebuffer_binding).framebuffer? == replacement
		assert framebuffer_source_native_int(framebuffer_binding) == int(replacement.object.native_handle_)
		assert context.get_error() == invalid_enum
		C.vox_gl_bind_buffer(0xbad, 0)
		context.bind_renderbuffer(renderbuffer, replacement_renderbuffer)
		assert context.get_parameter(renderbuffer_binding).renderbuffer? == replacement_renderbuffer
		assert framebuffer_source_native_int(renderbuffer_binding) == int(replacement_renderbuffer.object.native_handle_)
		assert context.get_error() == invalid_enum
		context.delete_framebuffer(replacement)
		assert context.bound_framebuffer_object == none
		assert context.get_parameter(framebuffer_binding).kind == .none
		other.native.make_current()
		context.delete_framebuffer(replacement)
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_error() == no_error
	}
}

fn test_source_read_framebuffer_bind_updates_the_single_retained_slot() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	drawing := context.create_framebuffer()
	reading := context.create_framebuffer()
	context.bind_framebuffer(framebuffer, drawing)
	context.bind_framebuffer(read_framebuffer, reading)
	assert context.get_parameter(framebuffer_binding).framebuffer? == reading
	assert framebuffer_source_native_int(framebuffer_binding) == int(drawing.object.native_handle_)
	assert framebuffer_source_native_int(0x8caa) == int(reading.object.native_handle_)
	assert context.get_error() == no_error
	context.delete_framebuffer(reading)
	assert context.get_parameter(framebuffer_binding).kind == .none
	assert framebuffer_source_native_int(framebuffer_binding) == int(drawing.object.native_handle_)
	assert framebuffer_source_native_int(0x8caa) == 0
	assert context.get_error() == no_error
}
