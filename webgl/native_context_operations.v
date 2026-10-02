// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Platform surface entry points. Native IOSurface/Vulkan/EGL handles are
// represented by deterministic ids at the standalone platform boundary.
module webgl

pub fn get_egl_config() bool {
	context := C.vox_egl_create(2)
	if context == unsafe { nil } { return false }
	C.vox_egl_destroy(context)
	return true
}

pub fn OpenGLContext.create(version WebGLVersion, options DrawingBufferOptions, supported []string) &OpenGLContext {
	return OpenGLContext.new(version, options, supported)
}

pub fn (mut context OpenGLContext) free_surface_resources() {
	C.vox_egl_free_surface(context.backend_)
	context.surface_allocated_ = false
	context.current_ = false
}

pub fn (context &OpenGLContext) canvas_id() ?u64 {
	if context.lost_ {
		return none
	}
	return u64(voidptr(context))
}

pub fn (mut context OpenGLContext) present_canvas_for_compositing(preserve_drawing_buffer bool) bool {
	return context.present_with_preserved_buffer(preserve_drawing_buffer)
}

pub fn (mut context OpenGLContext) clear_buffer_to_default_values() {
	context.dispatch('clear_buffer_to_default_values')
	C.vox_egl_clear_drawing_buffer(context.backend_)
	context.collect_native_error()
}

pub fn (mut context OpenGLContext) allocate_iosurface_painting_surface() {
	context.allocate_painting_surface_if_needed()
}

pub fn (mut context OpenGLContext) allocate_vkimage_painting_surface() {
	context.allocate_painting_surface_if_needed()
}

pub fn (context &OpenGLContext) surface() bool {
	return context.surface_allocated_
}

pub fn (context &OpenGLContext) default_renderbuffer() GLuint {
	return GLuint(C.vox_egl_default_renderbuffer(context.backend_))
}

pub fn (context &OpenGLContext) default_framebuffer() GLuint {
	return GLuint(C.vox_egl_default_framebuffer(context.backend_))
}

pub fn (context &OpenGLContext) webgl_version() WebGLVersion {
	return context.version
}
