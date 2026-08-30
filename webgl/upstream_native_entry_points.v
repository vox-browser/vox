// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Platform surface entry points. Native IOSurface/Vulkan/EGL handles are
// represented by deterministic ids at the standalone platform boundary.
module webgl

pub fn get_egl_config() bool {
	return true
}

pub fn OpenGLContext.create(version WebGLVersion, options DrawingBufferOptions, supported []string) &OpenGLContext {
	return OpenGLContext.new(version, options, supported)
}

pub fn (mut context OpenGLContext) free_surface_resources() {
	context.surface_allocated_ = false
	context.current_ = false
}

pub fn (mut context OpenGLContext) clear_buffer_to_default_values() {
	context.dispatch('clear_buffer_to_default_values')
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
	return if context.drawing_buffer_options.depth || context.drawing_buffer_options.stencil {
		GLuint(2)
	} else {
		GLuint(0)
	}
}

pub fn (context &OpenGLContext) default_framebuffer() GLuint {
	return if context.surface_allocated_ { GLuint(1) } else { GLuint(0) }
}

pub fn (context &OpenGLContext) webgl_version() WebGLVersion {
	return context.version
}
