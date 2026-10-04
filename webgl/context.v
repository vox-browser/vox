// Copyright (c) 2026, Ladybird contributors
// Copyright (c) 2024-2025, Aliaksandr Kalenik <kalenik.aliaksandr@gmail.com>
// Copyright (c) 2024-2025, Luke Wilde <luke@ladybird.org>
// Copyright (c) 2025, Undefine <undefine@undefine.pl>
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebGLRenderingContext, WebGLRenderingContextBase,
// WebGLRenderingContextImpl and the WebGL1 overload implementation.
module webgl

pub const max_webgl_drawing_buffer_dimension = 16384

@[heap]
pub struct WebGLRenderingContext {
pub:
	version    WebGLVersion
	attributes WebGLContextAttributes
pub mut:
	native &OpenGLContext
mut:
	next_handle                         GLuint = 1
	context_generation_                 u64
	error_                              GLenum
	context_lost_                       bool
	context_restore_requested_          bool
	context_events_                     []WebGLContextEvent
	xr_compatible_                      bool
	canvas_owner_                       voidptr
	enabled_extensions                  map[string]&WebGLExtension
	enabled_compressed_texture_formats_ []GLenum
	buffers                             map[GLuint]&WebGLBuffer
	framebuffers                        map[GLuint]&WebGLFramebuffer
	renderbuffers                       map[GLuint]&WebGLRenderbuffer
	textures                            map[GLuint]&WebGLTexture
	shaders                             map[GLuint]&WebGLShader
	programs                            map[GLuint]&WebGLProgram
	queries                             map[GLuint]&WebGLQuery
	samplers                            map[GLuint]&WebGLSampler
	syncs                               map[GLuint]&WebGLSync
	transform_feedbacks                 map[GLuint]&WebGLTransformFeedback
	vertex_arrays                       map[GLuint]&WebGLVertexArrayObject
	vertex_arrays_oes                   map[GLuint]&WebGLVertexArrayObjectOES
	bound_buffers                       map[GLenum]GLuint
	bound_buffer_objects                map[GLenum]&WebGLBuffer
	bound_framebuffer                   GLuint
	bound_framebuffer_object            ?&WebGLFramebuffer
	bound_renderbuffer                  GLuint
	bound_renderbuffer_object           ?&WebGLRenderbuffer
	bound_textures                      map[GLenum]GLuint
	bound_texture_objects               map[GLenum]&WebGLTexture
	current_program                     ?&WebGLProgram
	current_queries                     map[GLenum]&WebGLQuery
	current_transform_feedback          ?&WebGLTransformFeedback
	current_vertex_array                ?&WebGLVertexArrayObject
	current_vertex_array_oes            ?&WebGLVertexArrayObjectOES
	current_vertex_array_binding_       ?&WebGLObject
	unpack_flip_y_                      bool
	unpack_premultiply_alpha_           bool
	unpack_colorspace_conversion_       GLenum = browser_default_webgl
	unpack_state_                       PixelUnpackState = PixelUnpackState{}
	vertex_attrib_states_               map[GLuint]VertexAttribState
}

pub fn WebGLRenderingContext.new(version WebGLVersion, attributes WebGLContextAttributes, supported_native_extensions []string) &WebGLRenderingContext {
	native := OpenGLContext.new(version, DrawingBufferOptions{
		depth: attributes.depth
		stencil: attributes.stencil
		antialias: attributes.antialias
	}, supported_native_extensions)
	return &WebGLRenderingContext{
		version: version
		attributes: attributes
		native: native
		xr_compatible_: attributes.xr_compatible
	}
}

pub fn (context &WebGLRenderingContext) identity() u64 {
	return u64(voidptr(context))
}

// Realm and relevant-global tokens use the context identity in the standalone
// V model; wrappers created by the context forward this same token.
pub fn (context &WebGLRenderingContext) realm() u64 {
	return context.identity()
}

pub fn (context &WebGLRenderingContext) relevant_global_impl() u64 {
	return context.identity()
}

pub fn (context &WebGLRenderingContext) context_generation() u64 {
	return context.context_generation_
}

fn (mut context WebGLRenderingContext) allocate_handle() GLuint {
	handle := context.next_handle
	context.next_handle++
	return handle
}

pub fn (mut context WebGLRenderingContext) set_error(error_value GLenum) {
	if context.error_ == no_error {
		context.error_ = error_value
	}
}

pub fn (mut context WebGLRenderingContext) get_error() GLenum {
	// Source WebGLContextProxy::make_current() is empty. Its GetError sync call
	// selects the owning host only if the base body reaches the driver query.
	return context.get_error_value()
}

pub fn (context &WebGLRenderingContext) get_context_attributes() ?WebGLContextAttributes {
	if context.context_lost_ {
		return none
	}
	return context.attributes
}

pub fn (context &WebGLRenderingContext) is_context_lost() bool {
	return context.context_lost_
}

pub fn (context &WebGLRenderingContext) xr_compatible() bool {
	return context.xr_compatible_
}

pub fn (mut context WebGLRenderingContext) set_xr_compatible(xr_compatible bool) {
	context.xr_compatible_ = xr_compatible
}

pub fn (mut context WebGLRenderingContext) lose_context(status_message string) WebGLContextEvent {
	if context.context_lost_ {
		return WebGLContextEvent.new('webglcontextlost', WebGLContextEventInit{
			status_message: status_message
		})
	}
	context.context_lost_ = true
	context.native.set_lost()
	context.error_ = context_lost_webgl
	event := WebGLContextEvent.new('webglcontextlost', WebGLContextEventInit{
		status_message: status_message
	})
	context.context_events_ << event
	return event
}

pub fn (mut context WebGLRenderingContext) lose_context_from_compositor_loss() {
	context.lose_context('')
}

// This models canceling the queued webglcontextlost event with
// preventDefault(), which opts the page into restoration.
pub fn (mut context WebGLRenderingContext) request_context_restore() {
	if context.context_lost_ {
		context.context_restore_requested_ = true
	}
}

pub fn (mut context WebGLRenderingContext) reestablish_remote_context() bool {
	context.native.restore(context.native.get_supported_opengl_extensions())
	return true
}

pub fn (mut context WebGLRenderingContext) restore_context_after_compositor_reconnect() bool {
	if !context.context_lost_ || !context.context_restore_requested_ {
		return false
	}
	if !context.reestablish_remote_context() {
		return false
	}
	context.reset_context_state_after_loss()
	context.context_lost_ = false
	context.context_restore_requested_ = false
	context.error_ = no_error
	context.context_events_ << WebGLContextEvent.new('webglcontextrestored', WebGLContextEventInit{})
	return true
}

pub fn (mut context WebGLRenderingContext) take_context_events() []WebGLContextEvent {
	events := context.context_events_.clone()
	context.context_events_.clear()
	return events
}

pub fn (mut context WebGLRenderingContext) set_size(width int, height int) {
	final_width, final_height := initial_drawing_buffer_size(width, height)
	context.native.set_size(final_width, final_height)
}

pub fn (context &WebGLRenderingContext) drawing_buffer_width() int {
	width, _ := context.native.size()
	return width
}

pub fn (context &WebGLRenderingContext) drawing_buffer_height() int {
	_, height := context.native.size()
	return height
}

pub fn (context &WebGLRenderingContext) needs_to_present() bool {
	return context.native.needs_to_present()
}

pub fn (mut context WebGLRenderingContext) present() bool {
	return context.native.present_with_preserved_buffer(context.attributes.preserve_drawing_buffer)
}

pub fn (mut context WebGLRenderingContext) prepare_for_compositing() bool {
	return context.native.present_canvas_for_compositing(context.attributes.preserve_drawing_buffer)
}

pub fn (mut context WebGLRenderingContext) did_update_canvas_content() {
	context.native.notify_content_will_change()
}

fn initial_drawing_buffer_size(width int, height int) (int, int) {
	final_width := if width < 1 {
		1
	} else if width > max_webgl_drawing_buffer_dimension {
		max_webgl_drawing_buffer_dimension
	} else {
		width
	}
	final_height := if height < 1 {
		1
	} else if height > max_webgl_drawing_buffer_dimension {
		max_webgl_drawing_buffer_dimension
	} else {
		height
	}
	return final_width, final_height
}

pub fn (mut context WebGLRenderingContext) reset_to_default_state() {
 // Both current upstream WebGL context reset implementations are empty.
}

fn (mut context WebGLRenderingContext) initialize_restored_client_state() {
	context.error_ = no_error
	context.bound_buffers.clear()
	context.bound_buffer_objects.clear()
	context.bound_framebuffer = 0
	context.bound_framebuffer_object = none
	context.bound_renderbuffer = 0
	context.bound_renderbuffer_object = none
	context.bound_textures.clear()
	context.bound_texture_objects.clear()
	context.current_program = none
	context.unpack_flip_y_ = false
	context.unpack_premultiply_alpha_ = false
	context.unpack_colorspace_conversion_ = browser_default_webgl
	context.unpack_state_ = PixelUnpackState{}
}

// A restored compositor context owns a fresh GL object namespace. Advancing
// the generation invalidates every wrapper from the lost context without
// confusing it with an object explicitly deleted by script.
pub fn (mut context WebGLRenderingContext) reset_context_state_after_loss() {
	context.context_generation_++
	context.initialize_restored_client_state()
	context.reset_client_side_webgl_state()
}

pub fn (mut context WebGLRenderingContext) reset_client_side_webgl_state() {
	context.bound_buffers.clear()
	context.bound_buffer_objects.clear()
	context.bound_framebuffer = 0
	context.bound_framebuffer_object = none
	context.bound_renderbuffer = 0
	context.bound_renderbuffer_object = none
	context.bound_textures.clear()
	context.bound_texture_objects.clear()
	context.current_program = none
	context.current_queries.clear()
	context.current_transform_feedback = none
	context.current_vertex_array = none
	context.current_vertex_array_oes = none
	context.current_vertex_array_binding_ = none
}

pub fn (context &WebGLRenderingContext) current_vertex_array_binding() ?&WebGLObject {
	return context.current_vertex_array_binding_
}

pub fn (mut context WebGLRenderingContext) set_current_vertex_array_binding(vertex_array ?&WebGLObject) {
	context.current_vertex_array_binding_ = vertex_array
}

pub fn (mut context WebGLRenderingContext) create_buffer() &WebGLBuffer {
	handle := context.allocate_handle()
	context.native.make_current()
	native_handle := C.vox_gl_gen_object(0)
	buffer := &WebGLBuffer{
		object: WebGLObject{...new_object(context.identity(), context.context_generation_, handle), native_handle_: native_handle}
	}
	unsafe {
		context.buffers[handle] = buffer
	}
	return buffer
}

pub fn (mut context WebGLRenderingContext) create_framebuffer() &WebGLFramebuffer {
	handle := context.allocate_handle()
	context.native.make_current()
	native_handle := C.vox_gl_gen_object(1)
	framebuffer_object := &WebGLFramebuffer{
		object: WebGLObject{...new_object(context.identity(), context.context_generation_, handle), native_handle_: native_handle}
	}
	unsafe {
		context.framebuffers[handle] = framebuffer_object
	}
	return framebuffer_object
}

pub fn (mut context WebGLRenderingContext) create_renderbuffer() &WebGLRenderbuffer {
	handle := context.allocate_handle()
	context.native.make_current()
	native_handle := C.vox_gl_gen_object(2)
	renderbuffer_object := &WebGLRenderbuffer{
		object: WebGLObject{...new_object(context.identity(), context.context_generation_, handle), native_handle_: native_handle}
	}
	unsafe {
		context.renderbuffers[handle] = renderbuffer_object
	}
	return renderbuffer_object
}

pub fn (mut context WebGLRenderingContext) create_texture() &WebGLTexture {
	handle := context.allocate_handle()
	context.native.make_current()
	native_handle := C.vox_gl_gen_object(3)
	texture := &WebGLTexture{
		object: WebGLObject{...new_object(context.identity(), context.context_generation_, handle), native_handle_: native_handle}
	}
	unsafe {
		context.textures[handle] = texture
	}
	return texture
}

pub fn (mut context WebGLRenderingContext) create_shader(type_ GLenum) ?&WebGLShader {
	context.native.make_current()
	if type_ !in [vertex_shader, fragment_shader] {
		context.set_error(invalid_enum)
		return none
	}
	handle := context.allocate_handle()
	native_handle := C.vox_gl_create_shader(type_)
	shader := &WebGLShader{
		object: WebGLObject{...new_object(context.identity(), context.context_generation_, handle), native_handle_: native_handle}
		type_: type_
	}
	unsafe {
		context.shaders[handle] = shader
	}
	return shader
}

pub fn (mut context WebGLRenderingContext) create_program() &WebGLProgram {
	handle := context.allocate_handle()
	context.native.make_current()
	native_handle := C.vox_gl_create_program()
	program := &WebGLProgram{
		object: WebGLObject{...new_object(context.identity(), context.context_generation_, handle), native_handle_: native_handle}
	}
	unsafe {
		context.programs[handle] = program
	}
	return program
}

pub fn (context &WebGLRenderingContext) owns(object &WebGLObject) bool {
	return object.context_id == context.identity()
		&& !object.invalidated_for_context(context.context_generation_)
}

fn (mut context WebGLRenderingContext) object_handle_for_query(object &WebGLObject) ?GLuint {
	handle_result := object.handle_for_query(context.identity(), context.context_generation_) or {
		context.set_error(invalid_operation)
		return none
	}
	if !handle_result.has_value {
		return none
	}
	return handle_result.value
}

pub fn (mut context WebGLRenderingContext) bind_buffer(target GLenum, buffer ?&WebGLBuffer) {
    context.native.make_current()
    if value := buffer {
        mut mutable_value := unsafe { &WebGLBuffer(value) }
        if !context.owns(&value.object) || !mutable_value.is_compatible_with(target) {
            context.set_error(invalid_operation)
            return
        }
    }
    if target !in [array_buffer, element_array_buffer, copy_read_buffer, copy_write_buffer,
        pixel_pack_buffer, pixel_unpack_buffer, transform_feedback_buffer, uniform_buffer]
        || (context.version == .webgl1 && target !in [array_buffer, element_array_buffer]) {
        context.set_error(invalid_enum)
        return
    }
    if value := buffer {
        context.bound_buffers[target] = value.object.handle_
        unsafe { context.bound_buffer_objects[target] = value }
    } else {
        context.bound_buffers.delete(target)
        context.bound_buffer_objects.delete(target)
    }
    context.native.dispatch('bind_buffer', target, if value := buffer { value.object.handle_ } else { 0 })
    C.vox_gl_bind_buffer(target, if value := buffer { value.object.native_handle_ } else { 0 })
}

pub fn (mut context WebGLRenderingContext) buffer_data(target GLenum, data []u8, usage GLenum) {
    context.native.make_current()
    context.native.dispatch('buffer_data', target, data.len, usage)
    C.vox_gl_buffer_data(target, data.len, data.data, usage)
}

pub fn (mut context WebGLRenderingContext) buffer_data_size(target GLenum, size i64, usage GLenum) {
    context.native.make_current()
    context.native.dispatch('buffer_data', target, size, usage)
    C.vox_gl_buffer_data(target, size, unsafe { nil }, usage)
}

pub fn (mut context WebGLRenderingContext) buffer_sub_data(target GLenum, offset i64, data []u8) {
    context.native.make_current()
    context.native.dispatch('buffer_sub_data', target, offset, data.len)
    C.vox_gl_buffer_sub_data(target, offset, data.len, data.data)
}

pub fn (mut context WebGLRenderingContext) delete_buffer(buffer ?&WebGLBuffer) {
	context.native.make_current()
	if value := buffer {
		mut mutable_value := unsafe { &WebGLBuffer(value) }
		handle_result := mutable_value.object.handle_for_deletion(context.identity(), context.context_generation_) or {
			context.set_error(invalid_operation)
			return
		}
		if !handle_result.has_value {
			return
		}
		handle := value.object.bookkeeping_id()
		context.buffers.delete(handle)
		context.native.dispatch('delete_buffer', handle)
		C.vox_gl_delete_object(0, handle_result.value)
	}
}

pub fn (mut context WebGLRenderingContext) is_buffer(buffer ?&WebGLBuffer) bool {
	context.native.make_current()
	value := buffer or { return false }
	context.object_handle_for_query(&value.object) or { return false }
	return C.vox_gl_is_object(0,value.object.native_handle_) == 1
}

pub fn (mut context WebGLRenderingContext) shader_source(mut shader WebGLShader, source string) {
	context.native.make_current()
	if !context.owns(&shader.object) {
		context.set_error(invalid_operation)
		return
	}
	C.vox_gl_shader_source(shader.object.native_handle_, source.str, source.len)
}

pub fn (mut context WebGLRenderingContext) compile_shader(mut shader WebGLShader) {
	context.native.make_current()
	if !context.owns(&shader.object) {
		context.set_error(invalid_operation)
		return
	}
	C.vox_gl_compile_shader(shader.object.native_handle_)
	context.native.dispatch('compile_shader', shader.object.handle_)
}

pub fn (mut context WebGLRenderingContext) get_shader_source(shader &WebGLShader) ?string {
	context.native.make_current()
	if !context.owns(&shader.object) {
		context.set_error(invalid_operation)
		return none
	}
	return context.native.native_shader_source(shader.object.native_handle_)
}

pub fn (mut context WebGLRenderingContext) get_shader_info_log(shader &WebGLShader) ?string {
	context.native.make_current()
	if !context.owns(&shader.object) {
		context.set_error(invalid_operation)
		return none
	}
	return context.native.native_shader_log(shader.object.native_handle_)
}

pub fn (mut context WebGLRenderingContext) attach_shader(mut program WebGLProgram, shader &WebGLShader) {
	context.native.make_current()
	if !context.owns(&program.object) || !context.owns(&shader.object) {
		context.set_error(invalid_operation)
		return
	}
	if shader.type_ == vertex_shader {
		if program.attached_vertex_shader != none {
			context.set_error(invalid_operation)
			return
		}
	} else if shader.type_ == fragment_shader {
		if program.attached_fragment_shader != none {
			context.set_error(invalid_operation)
			return
		}
	}
	C.vox_gl_attach_shader(program.object.native_handle_, shader.object.native_handle_)
	match shader.type_ {
		vertex_shader { program.attached_vertex_shader = shader }
		fragment_shader { program.attached_fragment_shader = shader }
		else { panic('unreachable shader type') }
	}
}

pub fn (mut context WebGLRenderingContext) detach_shader(mut program WebGLProgram, shader &WebGLShader) {
	context.native.make_current()
	if !context.owns(&program.object) || !context.owns(&shader.object) {
		context.set_error(invalid_operation)
		return
	}
	C.vox_gl_detach_shader(program.object.native_handle_, shader.object.native_handle_)
	// The pinned source clears the typed retained slot after the driver call,
	// including when GL rejects an owned shader that was never attached.
	if shader.type_ == vertex_shader {
		program.attached_vertex_shader = none
	} else if shader.type_ == fragment_shader {
		program.attached_fragment_shader = none
	}
}

pub fn (mut context WebGLRenderingContext) link_program(mut program WebGLProgram) {
	context.native.make_current()
	if !context.owns(&program.object) {
		context.set_error(invalid_operation)
		return
	}
	C.vox_gl_link_program(program.object.native_handle_)
	context.native.dispatch('link_program', program.object.handle_)
}

pub fn (mut context WebGLRenderingContext) use_program(program ?&WebGLProgram) {
	context.native.make_current()
	if value := program {
		if !context.owns(&value.object) {
			context.set_error(invalid_operation)
			return
		}
	}
	C.vox_gl_use_program(if value := program { value.object.native_handle_ } else { 0 })
	context.current_program = program
	context.native.dispatch('use_program', if value := program { value.object.handle_ } else { 0 })
}

pub fn (mut context WebGLRenderingContext) validate_program(mut program WebGLProgram) {
	context.native.make_current()
	if !context.owns(&program.object) {
		context.set_error(invalid_operation)
		return
	}
	C.vox_gl_validate_program(program.object.native_handle_)
}

pub fn (mut context WebGLRenderingContext) get_uniform_location(mut program WebGLProgram, name string) ?&WebGLUniformLocation {
	context.native.make_current()
	if !context.owns(&program.object) {
		context.set_error(invalid_operation)
		return none
	}
	native_location := C.vox_gl_uniform_location(program.object.native_handle_, name.str)
	if native_location < 0 { return none }
	location := &WebGLUniformLocation{
		handle_: GLuint(native_location)
		parent_program: program
	}
	return location
}

pub fn (mut context WebGLRenderingContext) set_uniform(location ?&WebGLUniformLocation, values []f32) {
	value := location or { return }
	value.handle(context.current_program) or {
		context.set_error(invalid_operation)
		return
	}
	if values.len == 0 { return }
	if values.len > 4 { context.set_error(invalid_value); return }
	context.uniform_floats(location, values, values.len)
}

pub fn (mut context WebGLRenderingContext) pixel_storei(pname GLenum, parameter int) {
	// Source Proxy::make_current is empty; client-only returns issue no GL command.
	match pname {
		unpack_alignment {
			if parameter !in [1, 2, 4, 8] {
				context.set_error(invalid_value)
				return
			}
			context.unpack_state_ = PixelUnpackState{
				...context.unpack_state_
				alignment: u64(parameter)
			}
		}
		unpack_flip_y_webgl {
			context.unpack_flip_y_ = parameter != 0
			return
		}
		unpack_premultiply_alpha_webgl {
			context.unpack_premultiply_alpha_ = parameter != 0
			return
		}
		unpack_colorspace_conversion_webgl {
			// The pinned source stores this browser-only state without enum validation.
			context.unpack_colorspace_conversion_ = GLenum(parameter)
			return
		}
		unpack_row_length, unpack_skip_rows, unpack_skip_pixels {
			if context.version == .webgl2 && parameter >= 0 {
				match pname {
					unpack_row_length {
						context.unpack_state_ = PixelUnpackState{
							...context.unpack_state_
							row_length: u64(parameter)
						}
					}
					unpack_skip_rows {
						context.unpack_state_ = PixelUnpackState{
							...context.unpack_state_
							skip_rows: u64(parameter)
						}
					}
					unpack_skip_pixels {
						context.unpack_state_ = PixelUnpackState{
							...context.unpack_state_
							skip_pixels: u64(parameter)
						}
					}
					else {}
				}
			}
		}
		else {}
	}
	context.native.dispatch('pixel_storei', pname, parameter)
}

pub fn (mut context WebGLRenderingContext) enable(capability GLenum) {
	context.native.dispatch('enable', capability)
}

pub fn (mut context WebGLRenderingContext) disable(capability GLenum) {
	context.native.dispatch('disable', capability)
}

pub fn (mut context WebGLRenderingContext) is_enabled(capability GLenum) bool {
	// WebGLRenderingContextImpl::is_enabled forwards to the current GL context.
	context.native.make_current()
	result := C.vox_gl_is_enabled(capability) != 0
	return result
}

pub fn (mut context WebGLRenderingContext) enable_vertex_attrib_array(index GLuint) {
	context.native.dispatch('enable_vertex_attrib_array', index)
}

pub fn (mut context WebGLRenderingContext) disable_vertex_attrib_array(index GLuint) {
	context.native.dispatch('disable_vertex_attrib_array', index)
}

pub fn (mut context WebGLRenderingContext) clear_color(red f32, green f32, blue f32, alpha f32) {
	context.native.make_current()
	C.vox_gl_clear_color(red, green, blue, alpha)
}

pub fn (mut context WebGLRenderingContext) clear_depth(depth f32) {
	context.native.make_current()
	C.vox_gl_clear_depth(depth)
}

pub fn (mut context WebGLRenderingContext) clear_stencil(stencil int) {
	context.native.make_current()
	C.vox_gl_clear_stencil(stencil)
}

pub fn (mut context WebGLRenderingContext) color_mask(red bool, green bool, blue bool, alpha bool) {
	context.native.make_current()
	C.vox_gl_color_mask(int(red), int(green), int(blue), int(alpha))
}

pub fn (mut context WebGLRenderingContext) depth_mask(flag bool) {
	context.native.make_current()
	C.vox_gl_depth_mask(int(flag))
}

pub fn (mut context WebGLRenderingContext) clear(mask GLenum) {
	context.native.make_current()
	context.native.notify_painting_surface_content_will_change()
	context.native.did_update_canvas_content()
	context.native.dispatch('clear', mask)
}

pub fn (mut context WebGLRenderingContext) viewport(x int, y int, width int, height int) {
	context.native.make_current()
	context.native.dispatch('viewport', x, y, width, height)
}

pub fn (mut context WebGLRenderingContext) scissor(x int, y int, width int, height int) {
	context.native.make_current()
	context.native.dispatch('scissor', x, y, width, height)
}

pub fn (mut context WebGLRenderingContext) draw_arrays(mode GLenum, first int, count int) {
	context.native.make_current()
	context.native.notify_painting_surface_content_will_change()
	context.native.did_update_canvas_content()
	context.native.dispatch('draw_arrays', mode, first, count)
}

pub fn (mut context WebGLRenderingContext) draw_elements(mode GLenum, count int, type_ GLenum, offset i64) {
	context.native.make_current()
	context.native.notify_painting_surface_content_will_change()
	context.native.dispatch('draw_elements', mode, count, type_, offset)
	context.native.did_update_canvas_content()
}

// Native passthrough state commands retain ordering at the platform boundary.
pub fn (mut context WebGLRenderingContext) command(name string, args ...i64) {
	context.native.dispatch(name, ...args)
}
