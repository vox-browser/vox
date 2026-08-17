// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebGLObject and all WebGL resource wrapper implementation
// units. Context identity checks substitute for native handle ownership checks.
module webgl

@[heap]
pub struct WebGLObject {
pub:
	context_id u64
mut:
	handle_      GLuint
	invalidated_ bool
	label_       string
}

fn new_object(context_id u64, handle GLuint) WebGLObject {
	return WebGLObject{
		context_id: context_id
		handle_:    handle
	}
}

pub fn (object &WebGLObject) handle(context_id u64) !GLuint {
	if object.context_id != context_id || object.invalidated_ {
		return error('GL_INVALID_OPERATION')
	}
	return object.handle_
}

pub fn (object &WebGLObject) invalidated() bool {
	return object.invalidated_
}

pub fn (object &WebGLObject) label() string {
	return object.label_
}

pub fn (mut object WebGLObject) set_label(label string) {
	object.label_ = label
}

fn (mut object WebGLObject) invalidate() {
	object.invalidated_ = true
	object.handle_ = 0
}

@[heap]
pub struct WebGLBuffer {
pub mut:
	object WebGLObject
mut:
	target_ ?GLenum
	data_   []u8
	usage_  GLenum
}

pub fn (mut buffer WebGLBuffer) is_compatible_with(target GLenum) bool {
	if original := buffer.target_ {
		if target == element_array_buffer {
			return original == element_array_buffer
		}
		return original != element_array_buffer
	}
	buffer.target_ = target
	return true
}

pub fn (buffer &WebGLBuffer) bytes() []u8 {
	return buffer.data_.clone()
}

@[heap]
pub struct WebGLFramebuffer {
pub mut:
	object WebGLObject
}

@[heap]
pub struct WebGLRenderbuffer {
pub mut:
	object WebGLObject
}

@[heap]
pub struct WebGLTexture {
pub mut:
	object WebGLObject
mut:
	target_ ?GLenum
}

@[heap]
pub struct WebGLShader {
pub mut:
	object WebGLObject
pub:
	type_ GLenum
mut:
	source_   string
	compiled_ bool
	info_log_ string
}

@[heap]
pub struct WebGLProgram {
pub mut:
	object WebGLObject
mut:
	attached_vertex_shader   ?&WebGLShader
	attached_fragment_shader ?&WebGLShader
	linked_                  bool
	validated_               bool
	info_log_                string
	uniform_locations        map[string]&WebGLUniformLocation
}

@[heap]
pub struct WebGLQuery {
pub mut:
	object WebGLObject
mut:
	target_    ?GLenum
	active_    bool
	available_ bool
	result_    u64
}

@[heap]
pub struct WebGLSampler {
pub mut:
	object WebGLObject
mut:
	integer_parameters map[GLenum]int
	float_parameters   map[GLenum]f32
}

@[heap]
pub struct WebGLSync {
pub mut:
	object WebGLObject
mut:
	signaled_ bool
}

@[heap]
pub struct WebGLTransformFeedback {
pub mut:
	object WebGLObject
mut:
	active_ bool
	paused_ bool
}

@[heap]
pub struct WebGLVertexArrayObject {
pub mut:
	object WebGLObject
}

@[heap]
pub struct WebGLVertexArrayObjectOES {
pub mut:
	object WebGLObject
}

@[heap]
pub struct WebGLUniformLocation {
pub:
	handle_           GLuint
	parent_program_id GLuint
}

pub fn (location &WebGLUniformLocation) handle(current_program ?&WebGLProgram) !GLuint {
	program := current_program or { return error('GL_INVALID_OPERATION') }
	if program.object.handle_ != location.parent_program_id || program.object.invalidated_ {
		return error('GL_INVALID_OPERATION')
	}
	return location.handle_
}
