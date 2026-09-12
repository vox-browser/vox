// Copyright (c) 2026, Ladybird contributors
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
	bound_framebuffer                   GLuint
	bound_renderbuffer                  GLuint
	bound_textures                      map[GLenum]GLuint
	current_program                     ?&WebGLProgram
	current_queries                     map[GLenum]&WebGLQuery
	bound_samplers                      map[GLuint]GLuint
	current_transform_feedback          ?&WebGLTransformFeedback
	current_vertex_array                ?&WebGLVertexArrayObject
	current_vertex_array_oes            ?&WebGLVertexArrayObjectOES
	enabled_capabilities                map[GLenum]bool
	enabled_vertex_attributes           map[GLuint]bool
	clear_color_                        [4]f32
	clear_depth_                        f64 = 1.0
	clear_stencil_                      int
	color_mask_                         [4]bool = [true, true, true, true]!
	depth_mask_                         bool = true
	viewport_                           [4]int
	scissor_                            [4]int
	unpack_flip_y_                      bool
	unpack_premultiply_alpha_           bool
	unpack_colorspace_conversion_       GLenum = browser_default_webgl
	active_texture_                     GLenum = texture0
	blend_color_                        [4]f32
	line_width_                         f32 = 1.0
	depth_range_                        [2]f64 = [f64(0), 1]!
	pack_alignment_                     int = 4
	unpack_alignment_                   int = 4
	unpack_state_                       PixelUnpackState = PixelUnpackState{}
	generic_parameters_                 map[GLenum]WebGLParameterValue
	uniform_values_                     map[GLuint][]f32
	vertex_attrib_values_               map[GLuint][]f32
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
		enabled_capabilities: {
			dither: true
		}
		generic_parameters_: default_webgl_parameters()
		xr_compatible_: attributes.xr_compatible
	}
}

pub fn (context &WebGLRenderingContext) identity() u64 {
	return u64(voidptr(context))
}

pub fn (context &WebGLRenderingContext) context_generation() u64 {
	return context.context_generation_
}

fn (mut context WebGLRenderingContext) allocate_handle() GLuint {
	handle := context.next_handle
	context.next_handle++
	return handle
}

fn (mut context WebGLRenderingContext) set_error(error_value GLenum) {
	if context.error_ == no_error {
		context.error_ = error_value
	}
}

pub fn (mut context WebGLRenderingContext) get_error() GLenum {
	if context.context_lost_ {
		error_value := context.error_
		context.error_ = no_error
		return error_value
	}
	local_error := context.native.take_pending_local_error()
	if local_error != no_error {
		return local_error
	}
	error_value := context.error_
	context.error_ = no_error
	return error_value
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

pub fn (mut context WebGLRenderingContext) make_xr_compatible() !bool {
	if context.context_lost_ {
		context.xr_compatible_ = false
		return error('InvalidStateError: The WebGL context has been lost')
	}
	context.xr_compatible_ = true
	return true
}

pub fn (mut context WebGLRenderingContext) set_size(width int, height int) {
	final_width, final_height := initial_drawing_buffer_size(width, height)
	context.native.set_size(final_width, final_height)
	context.viewport_ = [0, 0, final_width, final_height]!
	context.scissor_ = [0, 0, final_width, final_height]!
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
	return context.native.present()
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
	context.error_ = no_error
	context.bound_buffers.clear()
	context.bound_framebuffer = 0
	context.bound_renderbuffer = 0
	context.bound_textures.clear()
	context.current_program = none
	context.enabled_capabilities.clear()
	context.enabled_capabilities[dither] = true
	context.enabled_vertex_attributes.clear()
	context.clear_color_ = [f32(0), 0, 0, 0]!
	context.clear_depth_ = 1
	context.clear_stencil_ = 0
	context.color_mask_ = [true, true, true, true]!
	context.depth_mask_ = true
	context.unpack_flip_y_ = false
	context.unpack_premultiply_alpha_ = false
	context.unpack_colorspace_conversion_ = browser_default_webgl
	context.active_texture_ = texture0
	context.pack_alignment_ = 4
	context.unpack_alignment_ = 4
	context.unpack_state_ = PixelUnpackState{}
	context.blend_color_ = [f32(0), 0, 0, 0]!
	context.line_width_ = 1
	context.depth_range_ = [f64(0), 1]!
	context.generic_parameters_ = default_webgl_parameters()
}

// A restored compositor context owns a fresh GL object namespace. Advancing
// the generation invalidates every wrapper from the lost context without
// confusing it with an object explicitly deleted by script.
pub fn (mut context WebGLRenderingContext) reset_context_state_after_loss() {
	context.context_generation_++
	context.reset_to_default_state()
	context.current_queries.clear()
	context.bound_samplers.clear()
	context.current_transform_feedback = none
	context.current_vertex_array = none
	context.current_vertex_array_oes = none
}

pub fn (mut context WebGLRenderingContext) create_buffer() &WebGLBuffer {
	handle := context.allocate_handle()
	buffer := &WebGLBuffer{
		object: new_object(context.identity(), context.context_generation_, handle)
	}
	unsafe {
		context.buffers[handle] = buffer
	}
	return buffer
}

pub fn (mut context WebGLRenderingContext) create_framebuffer() &WebGLFramebuffer {
	handle := context.allocate_handle()
	framebuffer_object := &WebGLFramebuffer{
		object: new_object(context.identity(), context.context_generation_, handle)
	}
	unsafe {
		context.framebuffers[handle] = framebuffer_object
	}
	return framebuffer_object
}

pub fn (mut context WebGLRenderingContext) create_renderbuffer() &WebGLRenderbuffer {
	handle := context.allocate_handle()
	renderbuffer_object := &WebGLRenderbuffer{
		object: new_object(context.identity(), context.context_generation_, handle)
	}
	unsafe {
		context.renderbuffers[handle] = renderbuffer_object
	}
	return renderbuffer_object
}

pub fn (mut context WebGLRenderingContext) create_texture() &WebGLTexture {
	handle := context.allocate_handle()
	texture := &WebGLTexture{
		object: new_object(context.identity(), context.context_generation_, handle)
	}
	unsafe {
		context.textures[handle] = texture
	}
	return texture
}

pub fn (mut context WebGLRenderingContext) create_shader(type_ GLenum) ?&WebGLShader {
	if type_ !in [vertex_shader, fragment_shader] {
		context.set_error(invalid_enum)
		return none
	}
	handle := context.allocate_handle()
	shader := &WebGLShader{
		object: new_object(context.identity(), context.context_generation_, handle)
		type_: type_
	}
	unsafe {
		context.shaders[handle] = shader
	}
	return shader
}

pub fn (mut context WebGLRenderingContext) create_program() &WebGLProgram {
	handle := context.allocate_handle()
	program := &WebGLProgram{
		object: new_object(context.identity(), context.context_generation_, handle)
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
	if target !in [array_buffer, element_array_buffer, copy_read_buffer, copy_write_buffer,
		pixel_pack_buffer, pixel_unpack_buffer, transform_feedback_buffer, uniform_buffer] {
		context.set_error(invalid_enum)
		return
	}
	if value := buffer {
		mut mutable_value := unsafe { &WebGLBuffer(value) }
		if !context.owns(&value.object) || !mutable_value.is_compatible_with(target) {
			context.set_error(invalid_operation)
			return
		}
		context.bound_buffers[target] = value.object.handle_
	} else {
		context.bound_buffers.delete(target)
	}
	context.native.dispatch('bind_buffer', target, context.bound_buffers[target])
}

pub fn (mut context WebGLRenderingContext) buffer_data(target GLenum, data []u8, usage GLenum) {
	handle := context.bound_buffers[target] or {
		context.set_error(invalid_operation)
		return
	}
	buffer := context.buffers[handle] or {
		context.set_error(invalid_operation)
		return
	}
	mut mutable_buffer := unsafe { &WebGLBuffer(buffer) }
	mutable_buffer.data_ = data.clone()
	mutable_buffer.usage_ = usage
	context.native.dispatch('buffer_data', target, data.len, usage)
}

pub fn (mut context WebGLRenderingContext) buffer_data_size(target GLenum, size i64, usage GLenum) {
	if size < 0 {
		context.set_error(invalid_value)
		return
	}
	context.buffer_data(target, []u8{len: int(size)}, usage)
}

pub fn (mut context WebGLRenderingContext) buffer_sub_data(target GLenum, offset i64, data []u8) {
	if offset < 0 {
		context.set_error(invalid_value)
		return
	}
	handle := context.bound_buffers[target] or {
		context.set_error(invalid_operation)
		return
	}
	buffer := context.buffers[handle] or {
		context.set_error(invalid_operation)
		return
	}
	mut mutable_buffer := unsafe { &WebGLBuffer(buffer) }
	if offset + data.len > mutable_buffer.data_.len {
		context.set_error(invalid_value)
		return
	}
	copy(mut mutable_buffer.data_[int(offset)..int(offset) + data.len], data)
	context.native.dispatch('buffer_sub_data', target, offset, data.len)
}

pub fn (mut context WebGLRenderingContext) delete_buffer(buffer ?&WebGLBuffer) {
	if value := buffer {
		mut mutable_value := unsafe { &WebGLBuffer(value) }
		handle_result := mutable_value.object.handle_for_deletion(context.identity(), context.context_generation_) or {
			context.set_error(invalid_operation)
			return
		}
		if !handle_result.has_value {
			return
		}
		handle := handle_result.value
		context.buffers.delete(handle)
		for target, bound in context.bound_buffers {
			if bound == handle { context.bound_buffers.delete(target) }
		}
		for index, state in context.vertex_attrib_states_ {
			if state.buffer_handle == handle {
				context.vertex_attrib_states_[index] = VertexAttribState{
					...state
					buffer_handle: 0
				}
			}
		}
		context.native.dispatch('delete_buffer', handle)
	}
}

pub fn (mut context WebGLRenderingContext) is_buffer(buffer ?&WebGLBuffer) bool {
	value := buffer or { return false }
	handle := context.object_handle_for_query(&value.object) or { return false }
	return handle in context.buffers
}

pub fn (mut context WebGLRenderingContext) shader_source(mut shader WebGLShader, source string) {
	if !context.owns(&shader.object) {
		context.set_error(invalid_operation)
		return
	}
	shader.source_ = source
	shader.compiled_ = false
}

pub fn (mut context WebGLRenderingContext) compile_shader(mut shader WebGLShader) {
	if !context.owns(&shader.object) {
		context.set_error(invalid_operation)
		return
	}
	shader.compiled_ = shader.source_.trim_space() != ''
	shader.info_log_ = if shader.compiled_ { '' } else { 'Shader source is empty' }
	context.native.dispatch('compile_shader', shader.object.handle_)
}

pub fn (context &WebGLRenderingContext) get_shader_source(shader &WebGLShader) ?string {
	if !context.owns(&shader.object) {
		return none
	}
	return shader.source_
}

pub fn (context &WebGLRenderingContext) get_shader_info_log(shader &WebGLShader) ?string {
	if !context.owns(&shader.object) {
		return none
	}
	return shader.info_log_
}

pub fn (mut context WebGLRenderingContext) attach_shader(mut program WebGLProgram, shader &WebGLShader) {
	if !context.owns(&program.object) || !context.owns(&shader.object) {
		context.set_error(invalid_operation)
		return
	}
	if shader.type_ == vertex_shader {
		if program.attached_vertex_shader != none {
			context.set_error(invalid_operation)
			return
		}
		program.attached_vertex_shader = shader
	} else {
		if program.attached_fragment_shader != none {
			context.set_error(invalid_operation)
			return
		}
		program.attached_fragment_shader = shader
	}
}

pub fn (mut context WebGLRenderingContext) detach_shader(mut program WebGLProgram, shader &WebGLShader) {
	if !context.owns(&program.object) || !context.owns(&shader.object) {
		context.set_error(invalid_operation)
		return
	}
	if shader.type_ == vertex_shader {
		attached := program.attached_vertex_shader or {
			context.set_error(invalid_operation)
			return
		}

		if attached != shader {
			context.set_error(invalid_operation)
			return
		}
		program.attached_vertex_shader = none
	} else {
		attached := program.attached_fragment_shader or {
			context.set_error(invalid_operation)
			return
		}

		if attached != shader {
			context.set_error(invalid_operation)
			return
		}
		program.attached_fragment_shader = none
	}
}

pub fn (mut context WebGLRenderingContext) link_program(mut program WebGLProgram) {
	if !context.owns(&program.object) {
		context.set_error(invalid_operation)
		return
	}
	vertex := program.attached_vertex_shader or {
		program.linked_ = false
		program.info_log_ = 'Missing vertex shader'
		return
	}

	fragment := program.attached_fragment_shader or {
		program.linked_ = false
		program.info_log_ = 'Missing fragment shader'
		return
	}

	program.linked_ = vertex.compiled_ && fragment.compiled_
	program.info_log_ = if program.linked_ { '' } else { 'Attached shader did not compile' }
	context.native.dispatch('link_program', program.object.handle_)
}

pub fn (mut context WebGLRenderingContext) use_program(program ?&WebGLProgram) {
	if value := program {
		if !context.owns(&value.object) || !value.linked_ {
			context.set_error(invalid_operation)
			return
		}
	}
	context.current_program = program
	context.native.dispatch('use_program', if value := program { value.object.handle_ } else { 0 })
}

pub fn (mut context WebGLRenderingContext) validate_program(mut program WebGLProgram) {
	if !context.owns(&program.object) {
		context.set_error(invalid_operation)
		return
	}
	program.validated_ = program.linked_
}

pub fn (mut context WebGLRenderingContext) get_uniform_location(mut program WebGLProgram, name string) ?&WebGLUniformLocation {
	if !context.owns(&program.object) || !program.linked_ {
		context.set_error(invalid_operation)
		return none
	}
	if name.contains('[') && !name.ends_with('[0]') {
		return none
	}
	if existing := program.uniform_locations[name] {
		return existing
	}
	location := &WebGLUniformLocation{
		handle_: GLuint(program.uniform_locations.len)
		parent_program_id: program.object.handle_
	}
	unsafe {
		program.uniform_locations[name] = location
	}
	return location
}

pub fn (mut context WebGLRenderingContext) set_uniform(location ?&WebGLUniformLocation, values []f32) {
	value := location or { return }
	value.handle(context.current_program) or {
		context.set_error(invalid_operation)
		return
	}
	mut args := [i64(value.handle_)]
	for item in values {
		args << i64(item)
	}
	context.native.dispatch('uniform', ...args)
}

pub fn (mut context WebGLRenderingContext) pixel_storei(pname GLenum, parameter int) {
	match pname {
		pack_alignment, unpack_alignment {
			if parameter !in [1, 2, 4, 8] {
				context.set_error(invalid_value)
				return
			}
			if pname == pack_alignment {
				context.pack_alignment_ = parameter
			} else {
				context.unpack_alignment_ = parameter
				context.unpack_state_ = PixelUnpackState{
					...context.unpack_state_
					alignment: u64(parameter)
				}
			}
			context.native.dispatch('pixel_storei', pname, parameter)
		}
		unpack_flip_y_webgl {
			context.unpack_flip_y_ = parameter != 0
		}
		unpack_premultiply_alpha_webgl {
			context.unpack_premultiply_alpha_ = parameter != 0
		}
		unpack_colorspace_conversion_webgl {
			if GLenum(parameter) !in [browser_default_webgl, GLenum(0)] {
				context.set_error(invalid_value)
				return
			}
			context.unpack_colorspace_conversion_ = GLenum(parameter)
		}
		pack_row_length, pack_skip_rows, pack_skip_pixels, unpack_row_length, unpack_skip_rows, unpack_skip_pixels, unpack_skip_images, unpack_image_height {
			if context.version != .webgl2 {
				context.set_error(invalid_enum)
				return
			}
			if parameter < 0 {
				context.set_error(invalid_value)
				return
			}
			context.generic_parameters_[pname] = integer_parameter(parameter)
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
			context.native.dispatch('pixel_storei', pname, parameter)
		}
		else {
			context.set_error(invalid_enum)
		}
	}
}

pub fn (mut context WebGLRenderingContext) enable(capability GLenum) {
	context.enabled_capabilities[capability] = true
	context.native.dispatch('enable', capability)
}

pub fn (mut context WebGLRenderingContext) disable(capability GLenum) {
	context.enabled_capabilities.delete(capability)
	context.native.dispatch('disable', capability)
}

pub fn (context &WebGLRenderingContext) is_enabled(capability GLenum) bool {
	return capability in context.enabled_capabilities
}

pub fn (mut context WebGLRenderingContext) enable_vertex_attrib_array(index GLuint) {
	context.enabled_vertex_attributes[index] = true
	context.native.dispatch('enable_vertex_attrib_array', index)
}

pub fn (mut context WebGLRenderingContext) disable_vertex_attrib_array(index GLuint) {
	context.enabled_vertex_attributes.delete(index)
	context.native.dispatch('disable_vertex_attrib_array', index)
}

pub fn (mut context WebGLRenderingContext) clear_color(red f32, green f32, blue f32, alpha f32) {
	context.clear_color_ = [clamp_unit(red), clamp_unit(green), clamp_unit(blue), clamp_unit(alpha)]!
	context.native.dispatch('clear_color', i64(red), i64(green), i64(blue), i64(alpha))
}

pub fn (mut context WebGLRenderingContext) clear_depth(depth f64) {
	context.clear_depth_ = if depth < 0 {
		0
	} else if depth > 1 {
		1
	} else {
		depth
	}
	context.native.dispatch('clear_depth', i64(context.clear_depth_))
}

pub fn (mut context WebGLRenderingContext) clear_stencil(stencil int) {
	context.clear_stencil_ = stencil
	context.native.dispatch('clear_stencil', stencil)
}

pub fn (mut context WebGLRenderingContext) color_mask(red bool, green bool, blue bool, alpha bool) {
	context.color_mask_ = [red, green, blue, alpha]!
}

pub fn (mut context WebGLRenderingContext) depth_mask(flag bool) {
	context.depth_mask_ = flag
}

pub fn (mut context WebGLRenderingContext) clear(mask GLenum) {
	context.native.dispatch('clear', mask)
}

pub fn (mut context WebGLRenderingContext) viewport(x int, y int, width int, height int) {
	if width < 0 || height < 0 {
		context.set_error(invalid_value)
		return
	}
	context.viewport_ = [x, y, width, height]!
	context.native.dispatch('viewport', x, y, width, height)
}

pub fn (mut context WebGLRenderingContext) scissor(x int, y int, width int, height int) {
	if width < 0 || height < 0 {
		context.set_error(invalid_value)
		return
	}
	context.scissor_ = [x, y, width, height]!
	context.native.dispatch('scissor', x, y, width, height)
}

pub fn (mut context WebGLRenderingContext) draw_arrays(mode GLenum, first int, count int) {
	if first < 0 || count < 0 {
		context.set_error(invalid_value)
		return
	}
	context.native.dispatch('draw_arrays', mode, first, count)
}

pub fn (mut context WebGLRenderingContext) draw_elements(mode GLenum, count int, type_ GLenum, offset i64) {
	if count < 0 || offset < 0 {
		context.set_error(invalid_value)
		return
	}
	if element_array_buffer !in context.bound_buffers {
		context.set_error(invalid_operation)
		return
	}
	context.native.dispatch('draw_elements', mode, count, type_, offset)
}

// Native passthrough state commands retain ordering at the platform boundary.
pub fn (mut context WebGLRenderingContext) command(name string, args ...i64) {
	context.native.dispatch(name, ...args)
}
