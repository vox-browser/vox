// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of OpenGLContext.cpp. IOSurface/Vulkan/Skia allocation and GL
// dispatch are represented as an explicit platform-state boundary.
module webgl

pub struct DrawingBufferOptions {
pub:
	depth     bool = true
	stencil   bool
	antialias bool = true
}

pub struct NativeCall {
pub:
	name string
	args []i64
}

@[heap]
pub struct OpenGLContext {
pub:
	version                WebGLVersion
	drawing_buffer_options DrawingBufferOptions
mut:
	width_                int
	height_               int
	current_              bool
	surface_allocated_    bool
	content_will_change_  bool
	needs_to_present_     bool
	lost_                 bool
	pending_local_error_  GLenum
	supported_extensions_ []string
	requested_extensions_ []string
	record_native_calls_  bool
	native_calls_         []NativeCall
}

pub fn OpenGLContext.new(version WebGLVersion, options DrawingBufferOptions, supported []string) &OpenGLContext {
	return &OpenGLContext{
		version: version
		drawing_buffer_options: options
		supported_extensions_: supported.clone()
	}
}

pub fn (mut context OpenGLContext) make_current() {
	if context.lost_ {
		return
	}
	context.current_ = true
}

pub fn (mut context OpenGLContext) set_lost() {
	context.lost_ = true
	context.current_ = false
}

pub fn (context &OpenGLContext) is_lost() bool {
	return context.lost_
}

pub fn (mut context OpenGLContext) restore(supported []string) {
	context.lost_ = false
	context.pending_local_error_ = no_error
	context.current_ = false
	context.surface_allocated_ = false
	context.content_will_change_ = false
	context.needs_to_present_ = false
	context.supported_extensions_ = supported.clone()
	context.requested_extensions_.clear()
	context.native_calls_.clear()
}

pub fn (mut context OpenGLContext) set_pending_local_error(error_value GLenum) {
	if context.pending_local_error_ == no_error {
		context.pending_local_error_ = error_value
	}
}

pub fn (mut context OpenGLContext) take_pending_local_error() GLenum {
	error_value := context.pending_local_error_
	context.pending_local_error_ = no_error
	return error_value
}

pub fn (mut context OpenGLContext) set_size(width int, height int) {
	if context.lost_ {
		return
	}
	if width == context.width_ && height == context.height_ {
		return
	}
	context.width_ = if width < 0 { 0 } else { width }
	context.height_ = if height < 0 { 0 } else { height }
	context.surface_allocated_ = false
}

pub fn (context &OpenGLContext) size() (int, int) {
	return context.width_, context.height_
}

pub fn (mut context OpenGLContext) allocate_painting_surface_if_needed() {
	if !context.lost_ && context.width_ > 0 && context.height_ > 0 {
		context.surface_allocated_ = true
	}
}

pub fn (mut context OpenGLContext) notify_content_will_change() {
	if context.lost_ {
		return
	}
	context.content_will_change_ = true
	context.needs_to_present_ = true
}

pub fn (mut context OpenGLContext) present() bool {
	if context.lost_ {
		return false
	}
	context.allocate_painting_surface_if_needed()
	if !context.surface_allocated_ {
		return false
	}
	context.needs_to_present_ = false
	context.content_will_change_ = false
	return true
}

pub fn (context &OpenGLContext) needs_to_present() bool {
	return context.needs_to_present_
}

pub fn (context &OpenGLContext) surface_allocated() bool {
	return context.surface_allocated_
}

pub fn (context &OpenGLContext) get_supported_opengl_extensions() []string {
	return context.supported_extensions_.clone()
}

pub fn (mut context OpenGLContext) request_extension(extension string) {
	if extension in context.supported_extensions_ && extension !in context.requested_extensions_ {
		context.requested_extensions_ << extension
	}
}

pub fn (mut context OpenGLContext) dispatch(name string, args ...i64) {
	if context.lost_ {
		return
	}
	context.make_current()
	if context.record_native_calls_ {
		context.native_calls_ << NativeCall{
			name: name
			args: args.clone()
		}
	}
	if name.starts_with('draw') || name == 'clear' { context.notify_content_will_change() }
}

// Native-call recording is a test/debug hook. Upstream dispatches directly to
// GL and does not allocate an ever-growing command transcript on the hot path.
pub fn (mut context OpenGLContext) set_native_call_recording(enabled bool) {
	context.record_native_calls_ = enabled
	if !enabled {
		context.native_calls_.clear()
	}
}

pub fn (context &OpenGLContext) native_calls() []NativeCall {
	return context.native_calls_.clone()
}
