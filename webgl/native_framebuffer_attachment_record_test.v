// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn C.glGetFramebufferAttachmentParameteriv(u32, u32, u32, &i32)

fn test_source_framebuffer_attachment_query_returns_actual_retained_deleted_records() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		framebuffer_object := context.create_framebuffer()
		texture := context.create_texture()
		renderbuffer_object := context.create_renderbuffer()
		context.bind_framebuffer(framebuffer, framebuffer_object)
		context.bind_texture(texture_2d, texture)
		context.tex_image2d(texture_2d, 0, int(rgba), 1, 1, 0, rgba, unsigned_byte,
			[u8(1), 2, 3, 255])
		context.framebuffer_texture2d(framebuffer, color_attachment0, texture_2d, texture, 0)
		before_texture := context.get_framebuffer_attachment_parameter(framebuffer,
			color_attachment0, framebuffer_attachment_object_name)
		assert before_texture.texture? == texture
		assert before_texture.renderbuffer == none
		context.delete_texture(texture)
		assert texture.object.invalidated()
		assert texture.object.handle_ !in context.textures
		mut native_type := i32(-1)
		C.glGetFramebufferAttachmentParameteriv(framebuffer, color_attachment0,
			framebuffer_attachment_object_type, &native_type)
		assert native_type == 0
		after_texture := context.get_framebuffer_attachment_parameter(framebuffer,
			color_attachment0, framebuffer_attachment_object_name)
		assert after_texture.texture? == texture
		assert after_texture.object == before_texture.object
		assert context.get_framebuffer_attachment_parameter(framebuffer, color_attachment0,
			framebuffer_attachment_object_type).integer == gl_texture
		assert context.get_error() == no_error
		context.bind_renderbuffer(renderbuffer, renderbuffer_object)
		context.renderbuffer_storage(renderbuffer, 0x8056, 1, 1)
		context.framebuffer_renderbuffer(framebuffer, color_attachment0, renderbuffer, renderbuffer_object)
		before_renderbuffer := context.get_framebuffer_attachment_parameter(framebuffer,
			color_attachment0, framebuffer_attachment_object_name)
		assert before_renderbuffer.renderbuffer? == renderbuffer_object
		assert before_renderbuffer.texture == none
		context.delete_renderbuffer(renderbuffer_object)
		assert renderbuffer_object.object.invalidated()
		assert renderbuffer_object.object.handle_ !in context.renderbuffers
		C.glGetFramebufferAttachmentParameteriv(framebuffer, color_attachment0,
			framebuffer_attachment_object_type, &native_type)
		assert native_type == 0
		after_renderbuffer := context.get_framebuffer_attachment_parameter(framebuffer,
			color_attachment0, framebuffer_attachment_object_name)
		assert after_renderbuffer.renderbuffer? == renderbuffer_object
		assert after_renderbuffer.object == before_renderbuffer.object
		assert context.get_framebuffer_attachment_parameter(framebuffer, color_attachment0,
			framebuffer_attachment_object_type).integer == renderbuffer
		assert context.get_error() == no_error
		context.framebuffer_renderbuffer(framebuffer, color_attachment0, renderbuffer, none)
		assert context.get_framebuffer_attachment_parameter(framebuffer, color_attachment0,
			framebuffer_attachment_object_type).integer == 0
		assert context.get_error() == no_error
	}
}
