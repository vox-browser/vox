// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of OpenGLContext.cpp. The native EGL context uses the upstream
// ANGLE backend and context attributes; drawing-surface state is retained here.
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
	backend_              voidptr
	surface_allocated_    bool
	content_will_change_  bool
	needs_to_present_     bool
	lost_                 bool
	pending_local_error_  GLenum
	supported_extensions_ []string
	requested_extensions_ []string
	record_native_calls_  bool
	native_calls_         []NativeCall
	viewport_             [4]int
	vendor_               string = 'Ladybird'
	renderer_             string = 'Ladybird V WebGL'
}

pub fn OpenGLContext.new(version WebGLVersion, options DrawingBufferOptions, supported []string) &OpenGLContext {
	backend := C.vox_egl_create(if version == .webgl1 { 2 } else { 3 })
	return &OpenGLContext{
		version: version
		drawing_buffer_options: options
		supported_extensions_: supported.clone()
		width_: 1
		height_: 1
		backend_: backend
		lost_: backend == unsafe { nil }
	}
}

pub fn (mut context OpenGLContext) make_current() {
	if context.lost_ {
		return
	}
	context.current_ = C.vox_egl_make_current(context.backend_) == 1
	if !context.current_ { context.lost_ = true }
	if context.current_ { context.allocate_painting_surface_if_needed() }
}

pub fn (mut context OpenGLContext) set_lost() {
	C.vox_egl_destroy(context.backend_)
	context.backend_ = unsafe { nil }
	context.lost_ = true
	context.current_ = false
}

pub fn (context &OpenGLContext) is_lost() bool {
	return context.lost_
}

pub fn (mut context OpenGLContext) restore(supported []string) {
	C.vox_egl_destroy(context.backend_)
	context.backend_ = C.vox_egl_create(if context.version == .webgl1 { 2 } else { 3 })
	context.lost_ = context.backend_ == unsafe { nil }
	context.pending_local_error_ = no_error
	context.current_ = false
	context.surface_allocated_ = false
	context.content_will_change_ = false
	context.needs_to_present_ = false
	context.supported_extensions_ = supported.clone()
	context.requested_extensions_.clear()
	context.native_calls_.clear()
	context.viewport_ = [0, 0, 0, 0]!
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
	if context.lost_ || context.surface_allocated_ || context.width_ <= 0 || context.height_ <= 0 {
		return
	}
	context.current_ = C.vox_egl_make_current(context.backend_) == 1
	if !context.current_ { context.lost_ = true; return }
	context.surface_allocated_ = C.vox_egl_allocate_surface(context.backend_, context.width_, context.height_, int(context.drawing_buffer_options.depth), int(context.drawing_buffer_options.stencil)) == 1
	context.collect_native_error()
	if !context.surface_allocated_ { return }
	context.viewport_ = [0, 0, context.width_, context.height_]!
}

pub fn (context &OpenGLContext) viewport() [4]int {
	return context.viewport_
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

pub fn (context &OpenGLContext) vendor() string {
	return context.vendor_
}

pub fn (context &OpenGLContext) renderer() string {
	return context.renderer_
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
	if !context.current_ { return }
	match name {
		'clear' { C.vox_gl_clear(u32(args[0])) }
		'viewport' { C.vox_gl_viewport(int(args[0]), int(args[1]), int(args[2]), int(args[3])) }
		'scissor' { C.vox_gl_scissor(int(args[0]), int(args[1]), int(args[2]), int(args[3])) }
		'enable' { C.vox_gl_enable(u32(args[0])) }
		'disable' { C.vox_gl_disable(u32(args[0])) }
		'pixel_storei' { C.vox_gl_pixel_storei(u32(args[0]), int(args[1])) }
		else {}
	}
	context.collect_native_error()
	if name == 'viewport' && args.len == 4 {
		context.viewport_ = [int(args[0]), int(args[1]), int(args[2]), int(args[3])]!
	}
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
