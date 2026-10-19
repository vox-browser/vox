// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebGLObject and all WebGL resource wrapper implementation
// units. source_handle_ stores Source m_handle (usually a generated proxy ID).
// native_handle_ stores the mapped driver name; handle_ keys compact wrappers.
// Context identity adapts the source GC owner.
module webgl

@[heap]
pub struct WebGLObject {
pub:
	context_id         u64
	context_generation u64
mut:
	handle_      GLuint
	source_handle_ GLuint
	native_handle_ GLuint
	invalidated_ bool
	label_       string
}

fn new_object(context_id u64, context_generation u64, handle GLuint, source_handle GLuint) WebGLObject {
	return WebGLObject{
		context_id: context_id
		context_generation: context_generation
		handle_: handle
		source_handle_: source_handle
	}
}

pub struct WebGLOptionalHandle {
pub:
	has_value bool
	value     GLuint
}

pub fn (object &WebGLObject) validate_context(context_id u64) ! {
	if object.context_id != context_id {
		return error('GL_INVALID_OPERATION')
	}
	return
}

pub fn (object &WebGLObject) invalidated_for_context(context_generation u64) bool {
	return object.invalidated_ || object.context_generation != context_generation
}

pub fn (object &WebGLObject) handle(context_id u64, context_generation u64) !GLuint {
	object.validate_context(context_id)!
	if object.invalidated_for_context(context_generation) {
		return error('GL_INVALID_OPERATION')
	}
	return object.source_handle_
}

pub fn (mut object WebGLObject) handle_for_deletion(context_id u64, context_generation u64) !WebGLOptionalHandle {
	object.validate_context(context_id)!
	if object.invalidated_for_context(context_generation) {
		return WebGLOptionalHandle{}
	}
	object.invalidated_ = true
	return WebGLOptionalHandle{
		has_value: true
		value: object.source_handle_
	}
}

pub fn (object &WebGLObject) handle_for_query(context_id u64, context_generation u64) !WebGLOptionalHandle {
	object.validate_context(context_id)!
	if object.invalidated_for_context(context_generation) {
		return WebGLOptionalHandle{}
	}
	return WebGLOptionalHandle{
		has_value: true
		value: object.source_handle_
	}
}

// The direct native adapter stores the compositor-side GLuint separately.
// Driver verification uses this name, rather than passing a Source proxy ID.
pub fn (object &WebGLObject) native_name() GLuint {
	return object.native_handle_
}

// Compact-host lookup IDs are separate from the source GLuint handle APIs.
pub fn (object &WebGLObject) bookkeeping_id() GLuint {
	return object.handle_
}

// The V translation uses context identity as its standalone relevant-global
// token; objects forward the token from their creating context.
pub fn (object &WebGLObject) relevant_global_impl() u64 {
	return object.context_id
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
}

@[heap]
pub struct WebGLBuffer {
pub mut:
	object WebGLObject
mut:
	target_ ?GLenum
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

@[heap]
pub struct WebGLFramebuffer {
pub mut:
	object WebGLObject
mut:
	attachments map[GLenum]WebGLFramebufferAttachment
}

pub struct WebGLFramebufferAttachment {
pub:
	texture        ?&WebGLTexture
	renderbuffer   ?&WebGLRenderbuffer
	texture_target GLenum
	texture_level  GLint
}

pub fn (framebuffer_object &WebGLFramebuffer) attachment(attachment GLenum) ?WebGLFramebufferAttachment {
	return framebuffer_object.attachments[attachment] or { none }
}

pub fn (mut framebuffer_object WebGLFramebuffer) set_renderbuffer_attachment(attachment GLenum, renderbuffer_object ?&WebGLRenderbuffer) {
	if renderbuffer := renderbuffer_object {
		framebuffer_object.attachments[attachment] = WebGLFramebufferAttachment{
			renderbuffer: renderbuffer
		}
	} else {
		framebuffer_object.attachments.delete(attachment)
	}
}

pub fn (mut framebuffer_object WebGLFramebuffer) set_texture_attachment(attachment GLenum, texture_object ?&WebGLTexture, texture_target GLenum, level GLint) {
	if texture_value := texture_object {
		framebuffer_object.attachments[attachment] = WebGLFramebufferAttachment{
			texture: texture_value
			texture_target: texture_target
			texture_level: level
		}
	} else {
		framebuffer_object.attachments.delete(attachment)
	}
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
}

@[heap]
pub struct WebGLShader {
pub mut:
	object WebGLObject
pub:
	type_ GLenum
}

@[heap]
pub struct WebGLProgram {
pub mut:
	object WebGLObject
mut:
	attached_vertex_shader   ?&WebGLShader
	attached_fragment_shader ?&WebGLShader
}

@[heap]
pub struct WebGLQuery {
pub mut:
	object WebGLObject
}

@[heap]
pub struct WebGLSampler {
pub mut:
	object WebGLObject
}

@[heap]
pub struct WebGLSync {
pub mut:
	object WebGLObject
mut:
	native_handle_ voidptr
	source_handle_ voidptr
}

pub struct WebGLOptionalSyncHandle {
pub:
	has_value bool
	value voidptr
}

pub fn (sync &WebGLSync) sync_handle(context_id u64, context_generation u64) !voidptr {
	sync.object.validate_context(context_id)!
	if sync.object.invalidated_for_context(context_generation) {
		return error('GL_INVALID_OPERATION')
	}
	return sync.source_handle_
}

pub fn (mut sync WebGLSync) sync_handle_for_deletion(context_id u64, context_generation u64) !WebGLOptionalSyncHandle {
	sync.object.validate_context(context_id)!
	if sync.object.invalidated_for_context(context_generation) {
		return WebGLOptionalSyncHandle{}
	}
	sync.object.invalidate()
	return WebGLOptionalSyncHandle{has_value: true, value: sync.source_handle_}
}

// The compositor-side GLsync pointer stays separate from the Source proxy
// pointer. This accessor is only the direct native adapter boundary.
pub fn (sync &WebGLSync) native_pointer() voidptr {
	return sync.native_handle_
}

@[heap]
pub struct WebGLTransformFeedback {
pub mut:
	object WebGLObject
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
	handle_        GLuint
	parent_program ?&WebGLProgram
}

pub fn (location &WebGLUniformLocation) handle(current_program ?&WebGLProgram) !GLuint {
	if program := current_program {
		parent := location.parent_program or { return error('GL_INVALID_OPERATION') }
		if voidptr(program) != voidptr(parent) {
			return error('GL_INVALID_OPERATION')
		}
	} else if location.parent_program != none {
		return error('GL_INVALID_OPERATION')
	}
	return location.handle_
}

pub fn (location &WebGLUniformLocation) relevant_global_impl() ?u64 {
	parent := location.parent_program or { return none }
	return parent.object.relevant_global_impl()
}
