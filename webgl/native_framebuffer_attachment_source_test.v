// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn C.glGetFramebufferAttachmentParameteriv(u32, u32, u32, &i32)

fn attachment_source_owner() {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == [i32(1), 2, 3, 4]!
}

fn attachment_source_native_name() int {
	mut value := 0
	C.glGetFramebufferAttachmentParameteriv(framebuffer, color_attachment0,
		framebuffer_attachment_object_name, &value)
	return value
}

fn test_source_framebuffer_attachment_owner_precedes_body_validation() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		foreign_texture := other.create_texture()
		foreign_renderbuffer := other.create_renderbuffer()
		for index in 0 .. 3 {
			target := if index == 0 { GLenum(0xbad) } else { framebuffer }
			attachment := if index == 1 { GLenum(0xbad) } else { color_attachment0 }
			object_target := if index == 2 { GLenum(0xbad) } else { renderbuffer }
			other.native.make_current()
			context.framebuffer_renderbuffer(target, attachment, object_target, foreign_renderbuffer)
			attachment_source_owner()
			assert context.get_error() == invalid_enum
			texture_target := if index == 2 { GLenum(0xbad) } else { texture_2d }
			other.native.make_current()
			context.framebuffer_texture2d(target, attachment, texture_target, foreign_texture, -1)
			attachment_source_owner()
			assert context.get_error() == invalid_enum
		}
		other.native.make_current()
		context.framebuffer_texture2d(framebuffer, color_attachment0, texture_2d, foreign_texture, -1)
		attachment_source_owner()
		assert context.get_error() == invalid_value
		other.native.make_current()
		context.framebuffer_texture2d(framebuffer, color_attachment0, texture_2d, foreign_texture, 0)
		attachment_source_owner()
		assert context.get_error() == invalid_operation
		other.native.make_current()
		context.framebuffer_renderbuffer(framebuffer, color_attachment0, renderbuffer, foreign_renderbuffer)
		attachment_source_owner()
		assert context.get_error() == invalid_operation
		owned := context.create_framebuffer()
		context.bind_framebuffer(framebuffer, owned)
		other.native.make_current()
		context.framebuffer_texture2d(framebuffer, color_attachment0, texture_2d, foreign_texture, 0)
		attachment_source_owner()
		assert context.get_error() == invalid_operation
		assert owned.attachment(color_attachment0) == none
		other.native.make_current()
		context.framebuffer_renderbuffer(framebuffer, color_attachment0, renderbuffer, foreign_renderbuffer)
		attachment_source_owner()
		assert context.get_error() == invalid_operation
		assert owned.attachment(color_attachment0) == none
	}
}

fn test_source_framebuffer_attachment_updates_retained_map_after_actual_driver_call() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		retained := context.create_framebuffer()
		driver := context.create_framebuffer()
		texture := context.create_texture()
		renderbuffer_object := context.create_renderbuffer()
		context.bind_texture(texture_2d, texture)
		context.tex_image2d(texture_2d, 0, int(rgba), 1, 1, 0, rgba, unsigned_byte,
			[u8(1), 2, 3, 255])
		context.bind_renderbuffer(renderbuffer, renderbuffer_object)
		context.renderbuffer_storage(renderbuffer, 0x8056, 1, 1)
		context.bind_framebuffer(framebuffer, retained)
		// The source slot and the real driver's binding can intentionally differ.
		C.vox_gl_bind_framebuffer(framebuffer, driver.object.native_handle_)
		context.framebuffer_texture2d(framebuffer, color_attachment0, texture_2d, texture, 0)
		assert attachment_source_native_name() == int(texture.object.native_handle_)
		assert retained.attachment(color_attachment0)?.texture? == texture
		assert driver.attachment(color_attachment0) == none
		assert context.get_error() == no_error
		context.framebuffer_renderbuffer(framebuffer, color_attachment0, renderbuffer, renderbuffer_object)
		assert attachment_source_native_name() == int(renderbuffer_object.object.native_handle_)
		assert retained.attachment(color_attachment0)?.renderbuffer? == renderbuffer_object
		assert driver.attachment(color_attachment0) == none
		assert context.get_error() == no_error
		// Native errors do not gate the source's subsequent attachment mutation.
		C.vox_gl_bind_framebuffer(framebuffer, 0)
		C.vox_gl_framebuffer_texture(framebuffer, color_attachment0, texture_2d,
			texture.object.native_handle_, 0)
		texture_error := C.vox_gl_get_error()
		assert texture_error != no_error
		context.framebuffer_texture2d(framebuffer, color_attachment0, texture_2d, texture, 0)
		assert retained.attachment(color_attachment0)?.texture? == texture
		assert context.get_error() == texture_error
		C.vox_gl_framebuffer_renderbuffer(framebuffer, color_attachment0, renderbuffer,
			renderbuffer_object.object.native_handle_)
		renderbuffer_error := C.vox_gl_get_error()
		assert renderbuffer_error != no_error
		context.framebuffer_renderbuffer(framebuffer, color_attachment0, renderbuffer, renderbuffer_object)
		assert retained.attachment(color_attachment0)?.renderbuffer? == renderbuffer_object
		assert context.get_error() == renderbuffer_error
		context.framebuffer_renderbuffer(framebuffer, color_attachment0, renderbuffer, none)
		assert retained.attachment(color_attachment0) == none
		assert context.get_error() == renderbuffer_error
		context.framebuffer_texture2d(framebuffer, color_attachment0, texture_2d, texture, 0)
		context.get_error()
		context.framebuffer_texture2d(framebuffer, color_attachment0, texture_2d, none, 0)
		assert retained.attachment(color_attachment0) == none
		assert context.get_error() == texture_error
		C.vox_gl_bind_framebuffer(framebuffer, driver.object.native_handle_)
		assert attachment_source_native_name() == int(renderbuffer_object.object.native_handle_)
		assert context.get_error() == no_error
	}
}
