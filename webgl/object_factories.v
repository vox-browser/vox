// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Direct factories and value-object accessors for the WebGL wrapper classes.
module webgl

pub fn WebGLExtension.create(mut context WebGLRenderingContext, name string, experimental bool) ?&WebGLExtension {
	return context.get_extension(name, experimental)
}

pub fn WebGLBuffer.create(mut context WebGLRenderingContext) &WebGLBuffer {
	return context.create_buffer()
}

pub fn WebGLFramebuffer.create(mut context WebGLRenderingContext) &WebGLFramebuffer {
	return context.create_framebuffer()
}

pub fn WebGLRenderbuffer.create(mut context WebGLRenderingContext) &WebGLRenderbuffer {
	return context.create_renderbuffer()
}

pub fn WebGLTexture.create(mut context WebGLRenderingContext) &WebGLTexture {
	return context.create_texture()
}

pub fn WebGLShader.create(mut context WebGLRenderingContext, type_ GLenum) ?&WebGLShader {
	return context.create_shader(type_)
}

pub fn (shader &WebGLShader) type_() GLenum {
	return shader.type_
}

pub fn WebGLProgram.create(mut context WebGLRenderingContext) &WebGLProgram {
	return context.create_program()
}

pub fn (program &WebGLProgram) attached_vertex_shader() ?&WebGLShader {
	return program.attached_vertex_shader
}

pub fn (mut program WebGLProgram) set_attached_vertex_shader(shader ?&WebGLShader) {
	program.attached_vertex_shader = shader
}

pub fn (program &WebGLProgram) attached_fragment_shader() ?&WebGLShader {
	return program.attached_fragment_shader
}

pub fn (mut program WebGLProgram) set_attached_fragment_shader(shader ?&WebGLShader) {
	program.attached_fragment_shader = shader
}

pub fn WebGLQuery.create(mut context WebGLRenderingContext) &WebGLQuery {
	return context.create_query()
}

pub fn WebGLSampler.create(mut context WebGLRenderingContext) &WebGLSampler {
	return context.create_sampler()
}

pub fn WebGLSync.create(mut context WebGLRenderingContext, condition GLenum, flags GLenum) ?&WebGLSync {
	return context.fence_sync(condition, flags)
}

pub fn WebGLTransformFeedback.create(mut context WebGLRenderingContext) &WebGLTransformFeedback {
	return context.create_transform_feedback()
}

pub fn WebGLVertexArrayObject.create(mut context WebGLRenderingContext) &WebGLVertexArrayObject {
	return context.create_vertex_array()
}

pub fn WebGLVertexArrayObjectOES.create(mut context WebGLRenderingContext) &WebGLVertexArrayObjectOES {
	return context.create_vertex_array_oes()
}

pub fn WebGLUniformLocation.create(handle GLuint, parent_program ?&WebGLProgram) &WebGLUniformLocation {
	return &WebGLUniformLocation{
		handle_: handle
		parent_program: parent_program
	}
}

pub fn WebGLActiveInfo.create(name string, type_ GLenum, size GLsizei) WebGLActiveInfo {
	return WebGLActiveInfo{
		name: name
		type_: type_
		size: size
	}
}

pub fn (info &WebGLActiveInfo) name() string {
	return info.name
}

pub fn (info &WebGLActiveInfo) type_() GLenum {
	return info.type_
}

pub fn (info &WebGLActiveInfo) size() GLsizei {
	return info.size
}

pub fn WebGLShaderPrecisionFormat.create(range_min int, range_max int, precision int) WebGLShaderPrecisionFormat {
	return WebGLShaderPrecisionFormat{
		range_min: range_min
		range_max: range_max
		precision: precision
	}
}

pub fn (format &WebGLShaderPrecisionFormat) range_min() int {
	return format.range_min
}

pub fn (format &WebGLShaderPrecisionFormat) range_max() int {
	return format.range_max
}

pub fn (format &WebGLShaderPrecisionFormat) precision() int {
	return format.precision
}

pub fn WebGLContextEvent.create(type_ string, init WebGLContextEventInit, time_stamp f64) WebGLContextEvent {
	return WebGLContextEvent{
		type_: type_
		status_message: init.status_message
		time_stamp_: time_stamp
	}
}

pub fn WebGLContextEvent.create_for_constructor(type_ string, init WebGLContextEventInit, time_stamp f64) WebGLContextEvent {
	return WebGLContextEvent.create(type_, init, time_stamp)
}

pub fn WebGLContextEvent.construct_impl(type_ string, init WebGLContextEventInit) WebGLContextEvent {
	return WebGLContextEvent.create_for_constructor(type_, init, 0)
}

pub fn (event &WebGLContextEvent) status_message() string {
	return event.status_message
}

pub fn (event &WebGLContextEvent) time_stamp() f64 {
	return event.time_stamp_
}
