// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of OpenGLContext.cpp. Native CGL, WGL and system EGL contexts
// provide the driver API; drawing-surface state is retained here.
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

pub struct WebGLPaintingSurface {
pub:
	width int
	height int
	// Source CPU surface readback is RGBA8888, premultiplied, with the top row first.
	pixels []u8
}

pub type WebGLCanvasContentChangedCallback = fn (voidptr)

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
	string_cache_         map[GLenum]string
	painting_pixels_      []u8
	canvas_content_owner_ voidptr
	canvas_content_changed_ ?WebGLCanvasContentChangedCallback
}

pub fn OpenGLContext.new(version WebGLVersion, options DrawingBufferOptions, supported []string) &OpenGLContext {
	backend := C.vox_egl_create(if version == .webgl1 { 2 } else { 3 })
	return &OpenGLContext{
		version: version
		drawing_buffer_options: options
		supported_extensions_: if supported.len > 0 { supported.clone() } else if backend != unsafe { nil } { native_gl_extensions() } else { []string{} }
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
	context.supported_extensions_ = if supported.len > 0 { supported.clone() } else if !context.lost_ { native_gl_extensions() } else { []string{} }
	context.requested_extensions_.clear()
	context.string_cache_.clear()
	context.native_calls_.clear()
	context.painting_pixels_.clear()
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

pub fn (mut context OpenGLContext) get_error() GLenum {
	// Generated Proxy::get_error is synchronous. HostWebGLContext's sync
	// receiver selects its own GL context before executing the native query.
	if context.lost_ { return no_error }
	context.make_current()
	if context.lost_ { return no_error }
	return GLenum(C.vox_gl_get_error())
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
	context.painting_pixels_.clear()
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
	if !context.surface_allocated_ { return }
}

pub fn (mut context OpenGLContext) notify_content_will_change() {
	if context.lost_ {
		return
	}
	context.notify_painting_surface_content_will_change()
	context.did_update_canvas_content()
}

// Direct CPU painting-surface adaptation of the source context notification.
// Concrete WebGLRenderingContext::did_update_canvas_content is ordered separately.
pub fn (mut context OpenGLContext) notify_painting_surface_content_will_change() {
	if context.lost_ {
		return
	}
	context.content_will_change_ = true
	context.needs_to_present_ = true
}

pub fn (mut context OpenGLContext) did_update_canvas_content() {
	if callback := context.canvas_content_changed_ { callback(context.canvas_content_owner_) }
}

pub fn (mut context OpenGLContext) bind_canvas_content_changed(owner voidptr, callback WebGLCanvasContentChangedCallback) {
	context.canvas_content_owner_ = owner
	context.canvas_content_changed_ = callback
}

pub fn (mut context OpenGLContext) present() bool {
	return context.present_with_preserved_buffer(false)
}

pub fn (mut context OpenGLContext) present_with_preserved_buffer(preserve_drawing_buffer bool) bool {
	defer { release_native_current() }
	if context.lost_ {
		return false
	}
	context.make_current()
	if context.lost_ || !context.surface_allocated_ {
		return false
	}
	// Upstream CPU painting surfaces wait for GPU writes before reading the rows.
	C.vox_gl_finish()
	frame := context.read_back_drawing_buffer() or { return false }
	context.painting_pixels_ = frame.pixels
	if !preserve_drawing_buffer { context.clear_buffer_to_default_values() }
	context.needs_to_present_ = false
	context.content_will_change_ = false
	return true
}

pub fn (mut context OpenGLContext) read_back_drawing_buffer() ?WebGLPaintingSurface {
	defer { release_native_current() }
	context.make_current()
	if !context.surface_allocated_ { return none }
	length := u64(context.width_) * u64(context.height_) * 4
	if length > u64(max_int) { context.set_pending_local_error(out_of_memory); return none }
	mut pixels := []u8{len:int(length)}
	if C.vox_egl_copy_drawing_buffer(context.backend_,context.width_,context.height_,pixels.data) != 1 { return none }
	return WebGLPaintingSurface{width:context.width_,height:context.height_,pixels:pixels}
}

pub fn (context &OpenGLContext) painting_surface() ?WebGLPaintingSurface {
	if !context.surface_allocated_ || context.painting_pixels_.len == 0 { return none }
	return WebGLPaintingSurface{width:context.width_,height:context.height_,pixels:context.painting_pixels_.clone()}
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

// WebGLContextProxyBase.cpp:393-408 owns one copied string per GL enum. Its
// cache lookup precedes loss handling; only a cold query reaches the host.
pub fn (mut context OpenGLContext) get_string(name GLenum) string {
	if cached := context.string_cache_[name] {
		return cached
	}
	context.make_current()
	if context.lost_ {
		return ''
	}
	value := native_gl_string(name)
	context.string_cache_[name] = value
	return value
}

pub fn (mut context OpenGLContext) vendor() string {
	return context.get_string(GLenum(0x1f00))
}

pub fn (mut context OpenGLContext) renderer() string {
	return context.get_string(GLenum(0x1f01))
}

pub fn (mut context OpenGLContext) request_extension(extension string) {
	if extension in context.supported_extensions_ && extension !in context.requested_extensions_ {
		context.make_current()
		C.vox_gl_request_extension(extension.str)
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
		'copy_tex_image2d' { C.vox_gl_copy_tex_image2d(u32(args[0]),int(args[1]),u32(args[2]),int(args[3]),int(args[4]),int(args[5]),int(args[6]),int(args[7])) }
		'copy_tex_sub_image2d' { C.vox_gl_copy_tex_sub_image2d(u32(args[0]),int(args[1]),int(args[2]),int(args[3]),int(args[4]),int(args[5]),int(args[6]),int(args[7])) }
		'tex_storage2d' { C.vox_gl_tex_storage2d(u32(args[0]),int(args[1]),u32(args[2]),int(args[3]),int(args[4])) }
		'tex_storage3d' { C.vox_gl_tex_storage3d(u32(args[0]),int(args[1]),u32(args[2]),int(args[3]),int(args[4]),int(args[5])) }
		'renderbuffer_storage_multisample' { C.vox_gl_renderbuffer_storage_multisample(u32(args[0]),int(args[1]),u32(args[2]),int(args[3]),int(args[4])) }
		'read_buffer' { C.vox_gl_read_buffer(u32(args[0])) }
		'draw_buffers', 'draw_buffers_webgl' { buffers:=args.map(u32(it));C.vox_gl_draw_buffers(buffers.len,buffers.data,int(name=='draw_buffers_webgl')) }
		'blit_framebuffer' { C.vox_gl_blit_framebuffer(int(args[0]),int(args[1]),int(args[2]),int(args[3]),int(args[4]),int(args[5]),int(args[6]),int(args[7]),u32(args[8]),u32(args[9])) }
        'enable_vertex_attrib_array' { C.vox_gl_vertex_attrib_enable(u32(args[0]), 1) }
        'disable_vertex_attrib_array' { C.vox_gl_vertex_attrib_enable(u32(args[0]), 0) }
        'vertex_attrib_pointer' { C.vox_gl_vertex_attrib_pointer(u32(args[0]), int(args[1]), u32(args[2]), int(args[3]), int(args[4]), args[5]) }
        'vertex_attrib_i_pointer' { C.vox_gl_vertex_attrib_i_pointer(u32(args[0]), int(args[1]), u32(args[2]), int(args[3]), args[4]) }
        'vertex_attrib_divisor', 'vertex_attrib_divisor_angle' { C.vox_gl_vertex_attrib_divisor(u32(args[0]), u32(args[1]), if context.version == .webgl2 { 3 } else { 2 }) }
        'draw_arrays' { C.vox_gl_draw_arrays(u32(args[0]), int(args[1]), int(args[2])) }
        'draw_elements' { C.vox_gl_draw_elements(u32(args[0]), int(args[1]), u32(args[2]), args[3]) }
        'draw_arrays_instanced', 'draw_arrays_instanced_angle' { C.vox_gl_draw_arrays_instanced(u32(args[0]), int(args[1]), int(args[2]), int(args[3]), if context.version == .webgl2 { 3 } else { 2 }) }
        'draw_elements_instanced', 'draw_elements_instanced_angle' { C.vox_gl_draw_elements_instanced(u32(args[0]), int(args[1]), u32(args[2]), args[3], int(args[4]), if context.version == .webgl2 { 3 } else { 2 }) }
        'draw_range_elements' { C.vox_gl_draw_range_elements(u32(args[0]), u32(args[1]), u32(args[2]), int(args[3]), u32(args[4]), args[5]) }
        'active_texture' { C.vox_gl_active_texture(u32(args[0])) }
        'blend_equation' { C.vox_gl_blend_equation(u32(args[0])) }
        'blend_equation_separate' { C.vox_gl_blend_equation_separate(u32(args[0]),u32(args[1])) }
        'blend_func' { C.vox_gl_blend_func(u32(args[0]),u32(args[1])) }
        'blend_func_separate' { C.vox_gl_blend_func_separate(u32(args[0]),u32(args[1]),u32(args[2]),u32(args[3])) }
        'cull_face' { C.vox_gl_cull_face(u32(args[0])) }
        'depth_func' { C.vox_gl_depth_func(u32(args[0])) }
        'finish' { C.vox_gl_finish() }
        'flush' { C.vox_gl_flush() }
        'front_face' { C.vox_gl_front_face(u32(args[0])) }
        'generate_mipmap' { C.vox_gl_generate_mipmap(u32(args[0])) }
        'hint' { C.vox_gl_hint(u32(args[0]),u32(args[1])) }
        'stencil_func' { C.vox_gl_stencil_func(u32(args[0]),int(args[1]),u32(args[2])) }
        'stencil_func_separate' { C.vox_gl_stencil_func_separate(u32(args[0]),u32(args[1]),int(args[2]),u32(args[3])) }
        'stencil_mask' { C.vox_gl_stencil_mask(u32(args[0])) }
        'stencil_mask_separate' { C.vox_gl_stencil_mask_separate(u32(args[0]),u32(args[1])) }
        'stencil_op' { C.vox_gl_stencil_op(u32(args[0]),u32(args[1]),u32(args[2])) }
        'stencil_op_separate' { C.vox_gl_stencil_op_separate(u32(args[0]),u32(args[1]),u32(args[2]),u32(args[3])) }
		'clear' { C.vox_gl_clear(u32(args[0])) }
		'viewport' { C.vox_gl_viewport(int(args[0]), int(args[1]), int(args[2]), int(args[3])) }
		'scissor' { C.vox_gl_scissor(int(args[0]), int(args[1]), int(args[2]), int(args[3])) }
		'enable' { C.vox_gl_enable(u32(args[0])) }
		'disable' { C.vox_gl_disable(u32(args[0])) }
		'pixel_storei' { C.vox_gl_pixel_storei(u32(args[0]), int(args[1])) }
		else {}
	}
	if context.record_native_calls_ {
		context.native_calls_ << NativeCall{
			name: name
			args: args.clone()
		}
	}
	// Source drawBuffers / WEBGL_draw_buffers only update GL draw-buffer state.
	// CPU presentation is invalidated by actual rendering commands.
	if (name.starts_with('draw') && name !in ['draw_buffers', 'draw_buffers_webgl',
		'draw_arrays', 'draw_elements', 'draw_arrays_instanced', 'draw_elements_instanced',
		'draw_range_elements'])
		|| name == 'blit_framebuffer' { context.notify_content_will_change() }
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
