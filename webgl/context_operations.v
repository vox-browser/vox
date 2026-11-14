// Copyright (c) 2026, Ladybird contributors
// Copyright (c) 2024-2025, Aliaksandr Kalenik <kalenik.aliaksandr@gmail.com>
// Copyright (c) 2024-2025, Luke Wilde <luke@ladybird.org>
// Copyright (c) 2025, Undefine <undefine@undefine.pl>
// SPDX-License-Identifier: BSD-2-Clause

// WebGLRenderingContextBase/Impl/Overloads entry points. Ladybird's six C++
// context layers share this one state record in V; native execution remains an
// ordered OpenGLContext dispatch after WebGL validation.
module webgl

pub enum WebGLParameterKind {
	none
	undefined_
	integer
	number
	boolean
	string_
	integers
	numbers
	booleans
	object
}

pub struct WebGLParameterValue {
pub:
	kind     WebGLParameterKind
	integer  i64
	number   f64
	boolean  bool
	text     string
	integers []i64
	numbers  []f64
	booleans []bool
	object   GLuint
	sampler ?&WebGLSampler
	buffer  ?&WebGLBuffer
	renderbuffer ?&WebGLRenderbuffer
	framebuffer ?&WebGLFramebuffer
	texture ?&WebGLTexture
	query ?&WebGLQuery
	shader ?&WebGLShader
	program ?&WebGLProgram
	vertex_array ?&WebGLVertexArrayObject
	vertex_array_oes ?&WebGLVertexArrayObjectOES
}

fn integer_parameter(value i64) WebGLParameterValue {
	return WebGLParameterValue{ kind: .integer, integer: value }
}

fn boolean_parameter(value bool) WebGLParameterValue {
	return WebGLParameterValue{ kind: .boolean, boolean: value }
}

fn (context &WebGLRenderingContext) retained_buffer_binding(target GLenum) ?&WebGLBuffer {
	if buffer := context.bound_buffer_objects[target] {
		return buffer
	}
	return none
}

fn (context &WebGLRenderingContext) retained_texture_binding(target GLenum) ?&WebGLTexture {
	if texture := context.bound_texture_objects[target] {
		return texture
	}
	return none
}

fn is_valid_framebuffer_binding_target(version WebGLVersion, target GLenum) bool {
	return target == framebuffer
		|| (version == .webgl2 && target in [read_framebuffer, draw_framebuffer])
}

fn is_valid_framebuffer_attachment(version WebGLVersion, draw_buffers_extension_enabled bool, attachment GLenum) bool {
	if attachment in [color_attachment0, depth_attachment, stencil_attachment,
		depth_stencil_attachment] {
		return true
	}
	return (version == .webgl2 || draw_buffers_extension_enabled)
		&& attachment > color_attachment0 && attachment <= color_attachment0 + 15
}

fn is_valid_framebuffer_texture_2d_target(target GLenum) bool {
	return target in [texture_2d, texture_cube_map_positive_x, texture_cube_map_negative_x,
		texture_cube_map_positive_y, texture_cube_map_negative_y, texture_cube_map_positive_z,
		texture_cube_map_negative_z]
}

fn is_cube_map_face(target GLenum) bool {
	return target >= texture_cube_map_positive_x && target <= texture_cube_map_negative_z
}

pub fn convert_value_to_context_attributes_dictionary(input ?ContextAttributeInput) !WebGLContextAttributes {
	attributes := convert_context_attributes(input)!
	// WebGLContextAttributes.cpp leaves this member at its default false.
	return WebGLContextAttributes{...attributes, xr_compatible: false}
}

pub fn fire_webgl_context_event(type_ string) WebGLContextEvent {
	return WebGLContextEvent.new(type_, WebGLContextEventInit{})
}

pub fn fire_webgl_context_creation_error() WebGLContextEvent {
	return WebGLContextEvent.new('webglcontextcreationerror', WebGLContextEventInit{})
}

pub fn WebGLRenderingContext.create(version WebGLVersion, attributes WebGLContextAttributes, supported_native_extensions []string) &WebGLRenderingContext {
	return WebGLRenderingContext.new(version, attributes, supported_native_extensions)
}

pub fn (context &WebGLRenderingContext) canvas_for_binding() voidptr {
	return context.canvas_owner_
}

pub fn (mut context WebGLRenderingContext) bind_canvas_for_binding(canvas voidptr) {
	context.canvas_owner_ = canvas
}

pub fn (context &WebGLRenderingContext) surface() bool {
	return context.native.surface()
}

pub fn (mut context WebGLRenderingContext) allocate_painting_surface_if_needed() {
	context.native.allocate_painting_surface_if_needed()
}

pub fn (context &WebGLRenderingContext) context() &OpenGLContext {
	return context.native
}

pub fn (mut context WebGLRenderingContext) get_error_value() GLenum {
	if context.context_lost_ {
		error_value := context.error_
		context.error_ = no_error
		return error_value
	}
	local_error := context.native.take_pending_local_error()
	if local_error != no_error {
		return local_error
	}
	context_error := context.native.get_error()
	if context_error != no_error {
		return context_error
	}
	error_value := context.error_
	context.error_ = no_error
	return error_value
}

pub fn get_offset_span(bytes []u8, offset u64, length u32) ![]u8 {
	return offset_span(bytes, offset, length)
}

pub fn span_from_float32_list(values []f32, source_offset u64, source_length u32) ![]f32 {
	return slice_f32(values, source_offset, source_length)
}

pub fn span_from_int32_list(values []int, source_offset u64, source_length u32) ![]int {
	return slice_int(values, source_offset, source_length)
}

pub fn span_from_uint32_list(values []u32, source_offset u64, source_length u32) ![]u32 {
	return slice_u32(values, source_offset, source_length)
}

fn slice_f32(values []f32, offset u64, length u32) ![]f32 {
	if offset > u64(values.len) {
		return error('offset exceeds source')
	}
	count := if length == 0 { u64(values.len) - offset } else { u64(length) }
	if offset + count < offset || offset + count > u64(values.len) {
		return error('slice exceeds source')
	}
	return values[int(offset)..int(offset + count)]
}

fn slice_int(values []int, offset u64, length u32) ![]int {
	if offset > u64(values.len) {
		return error('offset exceeds source')
	}
	count := if length == 0 { u64(values.len) - offset } else { u64(length) }
	if offset + count < offset || offset + count > u64(values.len) {
		return error('slice exceeds source')
	}
	return values[int(offset)..int(offset + count)]
}

fn slice_u32(values []u32, offset u64, length u32) ![]u32 {
	if offset > u64(values.len) {
		return error('offset exceeds source')
	}
	count := if length == 0 { u64(values.len) - offset } else { u64(length) }
	if offset + count < offset || offset + count > u64(values.len) {
		return error('slice exceeds source')
	}
	return values[int(offset)..int(offset + count)]
}

pub fn null_terminated_string(bytes []u8) string {
	for index, value in bytes {
		if value == 0 { return bytes[..index].bytestr() }
	}
	return bytes.bytestr()
}

pub fn (mut context WebGLRenderingContext) active_texture(texture GLenum) {
	context.native.make_current()
	context.command('active_texture', texture)
}

pub fn (mut context WebGLRenderingContext) bind_attrib_location(program &WebGLProgram, index GLuint, name string) {
	if !context.owns(&program.object) {
		context.set_error(invalid_operation)
		return
	}
	context.native.make_current()
	// Source record_bytes drops this generated command after loss.
	if !context.native.current_ { return }
	context.command('bind_attrib_location', program.object.handle_, index, name.len)
	C.vox_gl_bind_attrib_location(program.object.native_handle_, index, name.str)
}

pub fn (mut context WebGLRenderingContext) bind_framebuffer(target GLenum, framebuffer_object ?&WebGLFramebuffer) {
	context.native.make_current()
	handle := if value := framebuffer_object {
		if !context.owns(&value.object) {
			context.set_error(invalid_operation)
			return
		}
		value.object.handle_
	} else {
		GLuint(0)
	}
	context.command('bind_framebuffer', target, handle)
	C.vox_gl_bind_framebuffer(target, if value := framebuffer_object { value.object.native_handle_ } else { context.native.default_framebuffer() })
	context.bound_framebuffer = handle
	context.bound_framebuffer_object = framebuffer_object
}

pub fn (mut context WebGLRenderingContext) bind_renderbuffer(target GLenum, renderbuffer_object ?&WebGLRenderbuffer) {
	context.native.make_current()
	handle := if value := renderbuffer_object {
		if !context.owns(&value.object) {
			context.set_error(invalid_operation)
			return
		}
		value.object.handle_
	} else {
		GLuint(0)
	}
	context.command('bind_renderbuffer', target, handle)
	C.vox_gl_bind_renderbuffer(target, if value := renderbuffer_object { value.object.native_handle_ } else { context.native.default_renderbuffer() })
	context.bound_renderbuffer = handle
	context.bound_renderbuffer_object = renderbuffer_object
}

pub fn (mut context WebGLRenderingContext) bind_texture(target GLenum, texture ?&WebGLTexture) {
	context.native.make_current()
	handle := if value := texture {
		if !context.owns(&value.object) {
			context.set_error(invalid_operation)
			return
		}
		value.object.handle_
	} else {
		GLuint(0)
	}
	if target !in [texture_2d, texture_cube_map, texture_3d, texture_2d_array] || (target in [
		texture_3d,
		texture_2d_array,
	] && context.version != .webgl2) {
		context.set_error(invalid_enum)
		return
	}
	if handle == 0 {
		context.bound_textures.delete(target)
		context.bound_texture_objects.delete(target)
	} else {
		context.bound_textures[target] = handle
		if value := texture { unsafe { context.bound_texture_objects[target] = value } }
	}
	context.command('bind_texture', target, handle)
	C.vox_gl_bind_texture(target, if value := texture { value.object.native_handle_ } else { 0 })
}

pub fn (mut context WebGLRenderingContext) blend_color(red f32, green f32, blue f32, alpha f32) {
	context.native.make_current()
	C.vox_gl_blend_color(red, green, blue, alpha)
}

pub fn (mut context WebGLRenderingContext) blend_equation(mode GLenum) {
	context.command('blend_equation', mode)
}

pub fn (mut context WebGLRenderingContext) blend_equation_separate(rgb GLenum, alpha GLenum) {
	context.command('blend_equation_separate', rgb, alpha)
}

pub fn (mut context WebGLRenderingContext) blend_func(source GLenum, destination GLenum) {
	context.command('blend_func', source, destination)
}

pub fn (mut context WebGLRenderingContext) blend_func_separate(source_rgb GLenum, destination_rgb GLenum, source_alpha GLenum, destination_alpha GLenum) {
	context.command('blend_func_separate', source_rgb, destination_rgb, source_alpha, destination_alpha)
}

pub fn (mut context WebGLRenderingContext) check_framebuffer_status(target GLenum) GLenum {
	context.command('check_framebuffer_status', target)
	result := GLenum(C.vox_gl_framebuffer_status(target))
	return result
}

pub fn (mut context WebGLRenderingContext) copy_tex_image2d(target GLenum, level int, internal_format GLenum, x int, y int, width int, height int, border int) {
	context.native.make_current()
	context.command('copy_tex_image2d', target, level, internal_format, x, y, width, height, border)
}

pub fn (mut context WebGLRenderingContext) copy_tex_sub_image2d(target GLenum, level int, x_offset int, y_offset int, x int, y int, width int, height int) {
	context.native.make_current()
	context.command('copy_tex_sub_image2d', target, level, x_offset, y_offset, x, y, width, height)
}

pub fn (mut context WebGLRenderingContext) cull_face(mode GLenum) {
	context.command('cull_face', mode)
}

pub fn (mut context WebGLRenderingContext) delete_framebuffer(object ?&WebGLFramebuffer) {
	context.native.make_current()
	if value := object {
		mut mutable_value := unsafe { &WebGLFramebuffer(value) }
		handle_result := mutable_value.object.handle_for_deletion(context.identity(), context.context_generation_) or {
			context.set_error(invalid_operation)
			return
		}
		if !handle_result.has_value {
			return
		}
		handle := value.object.bookkeeping_id()
		context.framebuffers.delete(handle)
		context.command('delete_framebuffer', handle)
		C.vox_gl_delete_object(1, value.object.native_handle_)
		if bound := context.bound_framebuffer_object {
			if voidptr(bound) == voidptr(value) {
				context.bound_framebuffer = 0
				context.bound_framebuffer_object = none
			}
		}
	}
}

pub fn (mut context WebGLRenderingContext) delete_renderbuffer(object ?&WebGLRenderbuffer) {
	context.native.make_current()
	if value := object {
		mut mutable_value := unsafe { &WebGLRenderbuffer(value) }
		handle_result := mutable_value.object.handle_for_deletion(context.identity(), context.context_generation_) or {
			context.set_error(invalid_operation)
			return
		}
		if !handle_result.has_value {
			return
		}
		handle := value.object.bookkeeping_id()
		context.renderbuffers.delete(handle)
		context.command('delete_renderbuffer', handle)
		C.vox_gl_delete_object(2, value.object.native_handle_)
	}
}

pub fn (mut context WebGLRenderingContext) delete_texture(object ?&WebGLTexture) {
	context.native.make_current()
	if value := object {
		mut mutable_value := unsafe { &WebGLTexture(value) }
		handle_result := mutable_value.object.handle_for_deletion(context.identity(), context.context_generation_) or {
			context.set_error(invalid_operation)
			return
		}
		if !handle_result.has_value {
			return
		}
		handle := value.object.bookkeeping_id()
		context.textures.delete(handle)
		context.command('delete_texture', handle)
		C.vox_gl_delete_object(3, value.object.native_handle_)
		for target, bound in context.bound_texture_objects {
			if voidptr(bound) == voidptr(value) {
				context.bound_textures.delete(target)
				context.bound_texture_objects.delete(target)
			}
		}
	}
}

pub fn (mut context WebGLRenderingContext) delete_shader(object ?&WebGLShader) {
	if value := object {
		mut mutable_value := unsafe { &WebGLShader(value) }
		handle_result := mutable_value.object.handle_for_deletion(context.identity(), context.context_generation_) or {
			context.set_error(invalid_operation)
			return
		}
		if !handle_result.has_value {
			return
		}
		handle := value.object.bookkeeping_id()
		context.shaders.delete(handle)
		context.native.make_current()
		// Source invalidates the record, then lost record_bytes drops native deletion.
		if !context.native.current_ { return }
		C.vox_gl_delete_shader(value.object.native_handle_)
		context.command('delete_shader', handle)
	}
}

pub fn (mut context WebGLRenderingContext) delete_program(object ?&WebGLProgram) {
	if value := object {
		mut mutable_value := unsafe { &WebGLProgram(value) }
		handle_result := mutable_value.object.handle_for_deletion(context.identity(), context.context_generation_) or {
			context.set_error(invalid_operation)
			return
		}
		if !handle_result.has_value {
			return
		}
		handle := value.object.bookkeeping_id()
		context.programs.delete(handle)
		context.native.make_current()
		// Lost Source recording drops GL deletion, but still clears its retained slot.
		if context.native.current_ {
			C.vox_gl_delete_program(value.object.native_handle_)
		}
		if current := context.current_program {
			if voidptr(current) == voidptr(value) {
				context.current_program = none
			}
		}
		context.command('delete_program', handle)
	}
}

pub fn (mut context WebGLRenderingContext) depth_func(function GLenum) {
	context.command('depth_func', function)
}

pub fn (mut context WebGLRenderingContext) depth_range(near f32, far f32) {
	context.native.make_current()
	C.vox_gl_depth_range(near, far)
}

pub fn (mut context WebGLRenderingContext) finish() {
	context.command('finish')
}

pub fn (mut context WebGLRenderingContext) flush() {
	context.command('flush')
}

pub fn (mut context WebGLRenderingContext) front_face(mode GLenum) {
	context.command('front_face', mode)
}

pub fn (mut context WebGLRenderingContext) generate_mipmap(target GLenum) {
	context.command('generate_mipmap', target)
}

pub fn (mut context WebGLRenderingContext) hint(target GLenum, mode GLenum) {
	context.command('hint', target, mode)
}

pub fn (mut context WebGLRenderingContext) framebuffer_renderbuffer(target GLenum, attachment GLenum, renderbuffer_target GLenum, object ?&WebGLRenderbuffer) {
	context.native.make_current()
	if !is_valid_framebuffer_binding_target(context.version, target)
		|| !is_valid_framebuffer_attachment(context.version, context.extension_enabled('WEBGL_draw_buffers'), attachment)
		|| renderbuffer_target != renderbuffer {
		context.set_error(invalid_enum)
		return
	}
	framebuffer_object := context.bound_framebuffer_object or {
		context.set_error(invalid_operation)
		return
	}
	handle := if value := object {
		if !context.owns(&value.object) {
			context.set_error(invalid_operation)
			return
		}
		value.object.handle_
	} else {
		GLuint(0)
	}
	context.command('framebuffer_renderbuffer', target, attachment, renderbuffer_target, handle)
	C.vox_gl_framebuffer_renderbuffer(target, attachment, renderbuffer_target, if value := object { value.object.native_handle_ } else { 0 })
	mut mutable := unsafe { &WebGLFramebuffer(framebuffer_object) }
	mutable.set_renderbuffer_attachment(attachment, object)
}

pub fn (mut context WebGLRenderingContext) framebuffer_texture2d(target GLenum, attachment GLenum, texture_target GLenum, object ?&WebGLTexture, level int) {
	context.native.make_current()
	if !is_valid_framebuffer_binding_target(context.version, target)
		|| !is_valid_framebuffer_attachment(context.version, context.extension_enabled('WEBGL_draw_buffers'), attachment)
		|| !is_valid_framebuffer_texture_2d_target(texture_target) {
		context.set_error(invalid_enum)
		return
	}
	if level < 0 || (context.version == .webgl1 && level != 0) {
		context.set_error(invalid_value)
		return
	}
	framebuffer_object := context.bound_framebuffer_object or {
		context.set_error(invalid_operation)
		return
	}
	handle := if value := object {
		if !context.owns(&value.object) {
			context.set_error(invalid_operation)
			return
		}
		value.object.handle_
	} else {
		GLuint(0)
	}
	context.command('framebuffer_texture2d', target, attachment, texture_target, handle, level)
	C.vox_gl_framebuffer_texture(target, attachment, texture_target, if value := object { value.object.native_handle_ } else { 0 }, level)
	mut mutable := unsafe { &WebGLFramebuffer(framebuffer_object) }
	mutable.set_texture_attachment(attachment, object, texture_target, level)
}

pub fn (mut context WebGLRenderingContext) get_framebuffer_attachment_parameter(target GLenum, attachment GLenum, pname GLenum) WebGLParameterValue {
	context.native.make_current()
	if !is_valid_framebuffer_binding_target(context.version, target) {
		context.set_error(invalid_enum)
		return WebGLParameterValue{}
	}
	if context.bound_framebuffer == 0 {
		context.set_error(invalid_operation)
		return WebGLParameterValue{}
	}
	if !is_valid_framebuffer_attachment(context.version, context.extension_enabled('WEBGL_draw_buffers'), attachment) {
		context.set_error(invalid_enum)
		return WebGLParameterValue{}
	}

	framebuffer_object := context.bound_framebuffer_object or {
		context.set_error(invalid_operation)
		return WebGLParameterValue{}
	}
	framebuffer_attachment := framebuffer_object.attachment(attachment) or {
		if pname == framebuffer_attachment_object_type {
			return integer_parameter(0)
		}
		if pname != framebuffer_attachment_object_name || context.version == .webgl1 {
			context.set_error(if context.version == .webgl2 {
				invalid_operation
			} else {
				invalid_enum
			})
		}
		return WebGLParameterValue{}
	}

	match pname {
		framebuffer_attachment_object_type {
			return integer_parameter(if framebuffer_attachment.texture != none {
				gl_texture
			} else {
				renderbuffer
			})
		}
		framebuffer_attachment_object_name {
			if texture_object := framebuffer_attachment.texture {
				return WebGLParameterValue{
					kind: .object
					object: texture_object.object.handle_
					texture: texture_object
				}
			}
			if renderbuffer_object := framebuffer_attachment.renderbuffer {
				return WebGLParameterValue{
					kind: .object
					object: renderbuffer_object.object.handle_
					renderbuffer: renderbuffer_object
				}
			}
		}
		framebuffer_attachment_texture_level {
			if framebuffer_attachment.texture != none {
				return integer_parameter(framebuffer_attachment.texture_level)
			}
		}
		framebuffer_attachment_texture_cube_map_face {
			if framebuffer_attachment.texture != none {
				return integer_parameter(if is_cube_map_face(framebuffer_attachment.texture_target) {
					framebuffer_attachment.texture_target
				} else {
					0
				})
			}
		}
		else {}
	}
	context.set_error(invalid_enum)
	return WebGLParameterValue{}
}

pub fn (mut context WebGLRenderingContext) get_attached_shaders(program &WebGLProgram) ?[]&WebGLShader {
	if !context.owns(&program.object) {
		context.set_error(invalid_operation)
		return none
	}
	mut result := []&WebGLShader{}
	if shader := program.attached_vertex_shader { result << shader }
	if shader := program.attached_fragment_shader { result << shader }
	return result
}

pub fn (mut context WebGLRenderingContext) get_program_info_log(program &WebGLProgram) ?string {
	if !context.owns(&program.object) {
		context.set_error(invalid_operation)
		return none
	}
	return context.native.native_program_log(program.object.native_handle_)
}

pub fn (mut context WebGLRenderingContext) get_program_parameter(program &WebGLProgram, pname GLenum) WebGLParameterValue {
	if !context.owns(&program.object) {
		context.set_error(invalid_operation)
		return WebGLParameterValue{}
	}
	result := context.native.native_program_parameter_robust(program.object.native_handle_, pname)
	return match pname {
		attached_shaders, active_attributes, active_uniforms { integer_parameter(result) }
		transform_feedback_buffer_mode, transform_feedback_varyings, active_uniform_blocks {
			if context.version != .webgl2 {
				context.set_error(invalid_enum)
				WebGLParameterValue{}
			} else {
				integer_parameter(result)
			}
		}
		delete_status, link_status, validate_status { boolean_parameter(result == 1) }
		else {
			context.set_error(invalid_enum)
			WebGLParameterValue{}
		}
	}
}

pub fn (mut context WebGLRenderingContext) get_shader_parameter(shader &WebGLShader, pname GLenum) WebGLParameterValue {
	if !context.owns(&shader.object) {
		context.set_error(invalid_operation)
		return WebGLParameterValue{}
	}
	result := context.native.native_shader_parameter_robust(shader.object.native_handle_, pname)
	return match pname {
		shader_type { integer_parameter(result) }
		delete_status, compile_status { boolean_parameter(result == 1) }
		else {
			context.set_error(invalid_enum)
			WebGLParameterValue{}
		}
	}
}

pub fn (mut context WebGLRenderingContext) get_shader_precision_format(shader GLenum, precision GLenum) WebGLShaderPrecisionFormat {
	context.command('get_shader_precision_format')
	// C writes two C ints; V's int is 64-bit under current V.
	mut range := [i32(0), 0]!
	mut bits := i32(0)
	C.vox_gl_shader_precision(shader, precision, &range[0], &bits)
	return WebGLShaderPrecisionFormat.create(int(range[0]), int(range[1]), int(bits))
}

pub fn (mut context WebGLRenderingContext) get_buffer_parameter(target GLenum, pname GLenum) WebGLParameterValue {
    if pname !in [buffer_size, buffer_usage] { context.set_error(invalid_enum); return WebGLParameterValue{} }
    context.native.make_current()
    result := C.vox_gl_buffer_parameter(target, pname)
    return integer_parameter(result)
}

pub fn (mut context WebGLRenderingContext) get_parameter(pname GLenum) WebGLParameterValue {
	if (pname == fragment_shader_derivative_hint && context.version != .webgl2 && !context.extension_enabled('OES_standard_derivatives'))
		|| (pname == GLenum(0x8cdf) && context.version != .webgl2 && !context.extension_enabled('WEBGL_draw_buffers'))
		|| (pname == GLenum(0x8824) && context.version != .webgl2)
		|| (pname == GLenum(0x84ff) && !context.extension_enabled('EXT_texture_filter_anisotropic')) {
		context.set_error(invalid_enum)
		return WebGLParameterValue{}
	}
	shape := C.vox_gl_parameter_shape(pname,if context.version == .webgl2 {3} else {2})
	if shape != 0 {
		if shape == 51 { return WebGLParameterValue{kind:.string_,text:context.native.get_string(pname)} }
		context.native.make_current()
		mut values := [f64(0),0,0,0]!
		C.vox_gl_parameter(pname,shape,&values[0])
		count := shape % 10
		return match shape / 10 {
			1 { if count == 1 { integer_parameter(i64(values[0])) } else { WebGLParameterValue{kind:.integers,integers:values[..count].map(i64(it))} } }
			2,4 { if count == 1 { WebGLParameterValue{kind:.number,number:values[0]} } else { WebGLParameterValue{kind:.numbers,numbers:values[..count].clone()} } }
			else { if count == 1 { WebGLParameterValue{kind:.boolean,boolean:values[0]==1} } else { WebGLParameterValue{kind:.booleans,booleans:values[..count].map(it==1)} } }
		}
	}
	if pname == vertex_array_binding && context.version != .webgl2 {
		if !context.extension_enabled('OES_vertex_array_object') { context.set_error(invalid_enum);return WebGLParameterValue{} }
		array := context.current_vertex_array_oes or { return WebGLParameterValue{} }
		return WebGLParameterValue{kind:.object,object:array.object.handle_,vertex_array_oes:array}
	}
 match pname {
  array_buffer_binding,element_array_buffer_binding {
   target:=if pname==array_buffer_binding {array_buffer} else {element_array_buffer}
   handle:=context.bound_buffers[target] or {return WebGLParameterValue{}}
   return WebGLParameterValue{kind:.object,object:handle,buffer:context.retained_buffer_binding(target)}
  }
  framebuffer_binding {return if context.bound_framebuffer==0 {WebGLParameterValue{}} else {WebGLParameterValue{kind:.object,object:context.bound_framebuffer,framebuffer:context.bound_framebuffer_object}}}
  renderbuffer_binding {return if context.bound_renderbuffer==0 {WebGLParameterValue{}} else {WebGLParameterValue{kind:.object,object:context.bound_renderbuffer,renderbuffer:context.bound_renderbuffer_object}}}
  current_program {program:=context.current_program or {return WebGLParameterValue{}};return WebGLParameterValue{kind:.object,object:program.object.handle_,program:program}}
  texture_binding_2d,texture_binding_cube_map {
   target:=if pname==texture_binding_2d {texture_2d} else {texture_cube_map}
   handle:=context.bound_textures[target] or {return WebGLParameterValue{}}
   return WebGLParameterValue{kind:.object,object:handle,texture:context.retained_texture_binding(target)}
  }
  compressed_texture_formats {return WebGLParameterValue{kind:.integers,integers:context.enabled_compressed_texture_formats_.map(i64(it))}}
  unpack_flip_y_webgl {return boolean_parameter(context.unpack_flip_y_)}
  unpack_premultiply_alpha_webgl {return boolean_parameter(context.unpack_premultiply_alpha_)}
  unpack_colorspace_conversion_webgl {return integer_parameter(context.unpack_colorspace_conversion_)}
  unmasked_vendor_webgl,unmasked_renderer_webgl {
   if !context.extension_enabled('WEBGL_debug_renderer_info') {context.set_error(invalid_enum);return WebGLParameterValue{}}
   return WebGLParameterValue{kind:.string_,text:if pname==unmasked_vendor_webgl {context.native.vendor()} else {context.native.renderer()}}
  }
  else {}
 }
 if context.version==.webgl2 {
  match pname {
   // Source get_parameter returns zero without issuing a compositor query.
   max_client_wait_timeout_webgl {return integer_parameter(0)}
   texture_binding_3d,texture_binding_2d_array {
    target:=if pname==texture_binding_3d {texture_3d} else {texture_2d_array}
    handle:=context.bound_textures[target] or {return WebGLParameterValue{}}
    return WebGLParameterValue{kind:.object,object:handle,texture:context.retained_texture_binding(target)}
   }
   copy_read_buffer,copy_write_buffer,pixel_pack_buffer_binding,pixel_unpack_buffer_binding,uniform_buffer_binding,transform_feedback_buffer_binding {
    target:=match pname {copy_read_buffer {copy_read_buffer} copy_write_buffer {copy_write_buffer} pixel_pack_buffer_binding {pixel_pack_buffer} pixel_unpack_buffer_binding {pixel_unpack_buffer} uniform_buffer_binding {uniform_buffer} else {transform_feedback_buffer}}
    handle:=context.bound_buffers[target] or {return WebGLParameterValue{}}
    return WebGLParameterValue{kind:.object,object:handle,buffer:context.retained_buffer_binding(target)}
   }
   transform_feedback_binding {feedback:=context.current_transform_feedback or {return WebGLParameterValue{}};return WebGLParameterValue{kind:.object,object:feedback.object.handle_}}
   vertex_array_binding {array:=context.current_vertex_array or {return WebGLParameterValue{}};return WebGLParameterValue{kind:.object,object:array.object.handle_,vertex_array:array}}
   sampler_binding {
    context.native.make_current()
    mut handle:=i32(0)
    C.vox_gl_int_parameter(pname,&handle)
    logical:=context.allocate_handle()
    sampler:=&WebGLSampler{object:WebGLObject{...new_object(context.identity(),context.context_generation_,logical,GLuint(handle)),native_handle_:GLuint(handle)}}
    unsafe {context.samplers[logical]=sampler}
    return WebGLParameterValue{kind:.object,object:logical,sampler:sampler}
   }
   else {}
  }
 }
 context.set_error(invalid_enum)
 return WebGLParameterValue{}
}

pub fn (mut context WebGLRenderingContext) get_renderbuffer_parameter(target GLenum, pname GLenum) WebGLParameterValue {
 if pname !in [GLenum(0x8d42),0x8d43,0x8d44,0x8d50,0x8d51,0x8d52,0x8d53,0x8d54,0x8cab,0x8d55] {
  context.set_error(invalid_enum); return WebGLParameterValue{}
 }
 context.native.make_current()
 result:=C.vox_gl_renderbuffer_parameter(target,pname)
 return integer_parameter(result)
}

pub fn (mut context WebGLRenderingContext) get_tex_parameter(target GLenum, pname GLenum) WebGLParameterValue {
 mut queried_name:=pname
 mut boolean_result:=false
 mut float_result:=false
 match pname {
  texture_mag_filter,texture_min_filter,texture_wrap_s,texture_wrap_t {}
  GLenum(0x84fe) {
   if !context.extension_enabled('EXT_texture_filter_anisotropic') {context.set_error(invalid_enum);return WebGLParameterValue{}}
  }
  else {
   if context.version!=.webgl2 {context.set_error(invalid_enum);return WebGLParameterValue{}}
   match pname {
    GLenum(0x813c),0x884d,0x884c,0x82df,0x813d,0x8072 {}
    GLenum(0x912f) {boolean_result=true}
    // Preserve the current source's LOD query (IMMUTABLE_FORMAT -> Boolean).
    GLenum(0x813b),0x813a {queried_name=GLenum(0x912f);boolean_result=true;float_result=true}
    else {context.set_error(invalid_enum);return WebGLParameterValue{}}
   }
  }
 }
 context.native.make_current()
 result:=if float_result {f64(C.vox_gl_tex_float_parameter(target,queried_name))} else {f64(C.vox_gl_tex_parameter(target,queried_name))}
 return if boolean_result {WebGLParameterValue{kind:.boolean,boolean:result==1}} else {integer_parameter(i64(result))}
}

pub fn (context &WebGLRenderingContext) get_uniform(_ &WebGLProgram, _ ?&WebGLUniformLocation) WebGLParameterValue {
	// WebGLRenderingContextImpl.cpp:1997-2001 returns JS number zero with a FIXME.
	return integer_parameter(0)
}

pub fn (mut context WebGLRenderingContext) get_active_attrib(program &WebGLProgram, index GLuint) ?WebGLActiveInfo {
	if !context.owns(&program.object) { context.set_error(invalid_operation); return none }
	return context.native.native_active_info(program.object.native_handle_, index, false)
}

pub fn (mut context WebGLRenderingContext) get_active_uniform(program &WebGLProgram, index GLuint) ?WebGLActiveInfo {
	if !context.owns(&program.object) { context.set_error(invalid_operation); return none }
	return context.native.native_active_info(program.object.native_handle_, index, true)
}

pub fn (mut context WebGLRenderingContext) get_attrib_location(program &WebGLProgram, name string) int {
	if !context.owns(&program.object) { context.set_error(invalid_operation); return -1 }
	context.native.make_current()
	result := C.vox_gl_attrib_location(program.object.native_handle_, name.str)
	return result
}

pub fn (mut context WebGLRenderingContext) get_vertex_attrib(index GLuint, pname GLenum) WebGLParameterValue {
    if pname == current_vertex_attrib {
        context.native.make_current()
        mut values := []f32{len:4}
        C.vox_gl_vertex_attrib_float_parameter(index,values.data)
        return WebGLParameterValue{kind:.numbers,numbers:values.map(f64(it))}
    }
    if pname == vertex_attrib_array_divisor && context.version != .webgl2 && !context.extension_enabled('ANGLE_instanced_arrays') {
        context.set_error(invalid_enum); return WebGLParameterValue{}
    }
    if pname == vertex_attrib_array_integer && context.version != .webgl2 {
        context.set_error(invalid_enum); return WebGLParameterValue{}
    }
    if pname !in [vertex_attrib_array_buffer_binding,vertex_attrib_array_divisor,vertex_attrib_array_enabled,vertex_attrib_array_integer,vertex_attrib_array_normalized,vertex_attrib_array_size,vertex_attrib_array_stride,vertex_attrib_array_type] {
        context.set_error(invalid_enum); return WebGLParameterValue{}
    }
    context.native.make_current()
    value := C.vox_gl_vertex_attrib_parameter(index,pname)
    if pname == vertex_attrib_array_buffer_binding {
        handle := context.allocate_handle()
        buffer := &WebGLBuffer{object: WebGLObject{...new_object(context.identity(),context.context_generation_,handle,GLuint(value)),native_handle_:GLuint(value)}}
        unsafe { context.buffers[handle] = buffer }
        return WebGLParameterValue{kind:.object,object:handle,buffer:buffer}
    }
    if pname in [vertex_attrib_array_enabled,vertex_attrib_array_integer,vertex_attrib_array_normalized] {
        return WebGLParameterValue{kind:.boolean,boolean:value == 1}
    }
    return integer_parameter(value)
}

pub fn (mut context WebGLRenderingContext) get_vertex_attrib_offset(index GLuint, pname GLenum) i64 {
    if pname != vertex_attrib_array_pointer { context.set_error(invalid_enum); return 0 }
    context.native.make_current()
    result := C.vox_gl_vertex_attrib_offset(index)
    return result
}

pub fn (mut context WebGLRenderingContext) is_framebuffer(value ?&WebGLFramebuffer) bool {
	context.native.make_current()
	object := value or { return false }
	context.object_handle_for_query(&object.object) or { return false }
	return C.vox_gl_is_object(1,object.object.native_handle_) == 1
}

pub fn (mut context WebGLRenderingContext) is_renderbuffer(value ?&WebGLRenderbuffer) bool {
	context.native.make_current()
	object := value or { return false }
	context.object_handle_for_query(&object.object) or { return false }
	return C.vox_gl_is_object(2,object.object.native_handle_) == 1
}

pub fn (mut context WebGLRenderingContext) is_texture(value ?&WebGLTexture) bool {
	context.native.make_current()
	object := value or { return false }
	context.object_handle_for_query(&object.object) or { return false }
	return C.vox_gl_is_object(3,object.object.native_handle_) == 1
}

pub fn (mut context WebGLRenderingContext) is_shader(value ?&WebGLShader) bool {
	object := value or { return false }
	context.object_handle_for_query(&object.object) or { return false }
	context.native.make_current()
	// Source's generated sync proxy suppresses dispatch after loss and returns
	// the value-initialized GLboolean, without querying another current owner.
	if !context.native.current_ { return false }
	return C.vox_gl_is_object(9,object.object.native_handle_) == 1
}

pub fn (mut context WebGLRenderingContext) is_program(value ?&WebGLProgram) bool {
	object := value or { return false }
	context.object_handle_for_query(&object.object) or { return false }
	context.native.make_current()
	// Source's generated Boolean sync query returns its initialized default
	// when lost, without dispatching to any other current native context.
	if !context.native.current_ { return false }
	return C.vox_gl_is_object(10,object.object.native_handle_) == 1
}

pub fn (mut context WebGLRenderingContext) line_width(width f32) {
	context.native.make_current()
	C.vox_gl_line_width(width)
}

pub fn (mut context WebGLRenderingContext) polygon_offset(factor f32, units f32) {
	context.native.make_current()
	C.vox_gl_polygon_offset(factor, units)
}

pub fn (mut context WebGLRenderingContext) renderbuffer_storage(target GLenum, internal_format GLenum, width int, height int) {
	context.native.make_current()
	// Source GL_DEPTH_STENCIL is stored as GL_DEPTH24_STENCIL8.
	format := if internal_format == GLenum(0x84f9) { GLenum(0x88f0) } else { internal_format }
	context.command('renderbuffer_storage', target, format, width, height)
	C.vox_gl_renderbuffer_storage(target, format, width, height)
}

pub fn (mut context WebGLRenderingContext) sample_coverage(value f32, invert bool) {
	context.native.make_current()
	C.vox_gl_sample_coverage(value, int(invert))
}

pub fn (mut context WebGLRenderingContext) stencil_func(function GLenum, reference int, mask GLuint) {
	context.command('stencil_func', function, reference, mask)
}

pub fn (mut context WebGLRenderingContext) stencil_func_separate(face GLenum, function GLenum, reference int, mask GLuint) {
	context.command('stencil_func_separate', face, function, reference, mask)
}

pub fn (mut context WebGLRenderingContext) stencil_mask(mask GLuint) {
	context.command('stencil_mask', mask)
}

pub fn (mut context WebGLRenderingContext) stencil_mask_separate(face GLenum, mask GLuint) {
	context.command('stencil_mask_separate', face, mask)
}

pub fn (mut context WebGLRenderingContext) stencil_op(fail GLenum, depth_fail GLenum, pass GLenum) {
	context.command('stencil_op', fail, depth_fail, pass)
}

pub fn (mut context WebGLRenderingContext) stencil_op_separate(face GLenum, fail GLenum, depth_fail GLenum, pass GLenum) {
	context.command('stencil_op_separate', face, fail, depth_fail, pass)
}

pub fn (mut context WebGLRenderingContext) tex_parameteri(target GLenum, pname GLenum, parameter int) {
	context.native.make_current()
	C.vox_gl_tex_parameteri(target, pname, parameter)
}

pub fn (mut context WebGLRenderingContext) tex_parameterf(target GLenum, pname GLenum, parameter f32) {
	context.native.make_current()
	C.vox_gl_tex_parameterf(target, pname, parameter)
}

fn (mut context WebGLRenderingContext) uniform_floats(location ?&WebGLUniformLocation, values []f32, width int) {
 context.native.make_current()
 value := location or { return }
 value.handle(context.current_program) or { context.set_error(invalid_operation); return }

 if values.len % width != 0 { context.set_error(invalid_value); return }
 C.vox_gl_uniform_floats(int(value.handle_), width, values.len / width, values.data)
}

fn (mut context WebGLRenderingContext) uniform_ints(location ?&WebGLUniformLocation, values []int, width int) {
 context.native.make_current()
 value := location or { return }
 value.handle(context.current_program) or { context.set_error(invalid_operation); return }

 if values.len % width != 0 { context.set_error(invalid_value); return }
 native_values := values.map(i32(it))
 defer { unsafe { native_values.free() } }
 C.vox_gl_uniform_ints(int(value.handle_), width, native_values.len / width, native_values.data)
}

fn (mut context WebGLRenderingContext) uniform_uints(location ?&WebGLUniformLocation, values []u32, width int) {
 context.native.make_current()
 value := location or { return }
 value.handle(context.current_program) or { context.set_error(invalid_operation); return }
 if !context.require_webgl2() { return }
 if values.len % width != 0 { context.set_error(invalid_value); return }
 C.vox_gl_uniform_uints(int(value.handle_), width, values.len / width, values.data)
}

fn (mut context WebGLRenderingContext) scalar_uniform_location(location ?&WebGLUniformLocation) ?GLuint {
	context.native.make_current()
	if value := location {
		return value.handle(context.current_program) or {
			context.set_error(invalid_operation)
			return none
		}
	}
	return GLuint(0)
}

pub fn (mut context WebGLRenderingContext) uniform1f(location ?&WebGLUniformLocation, x f32) {
	handle := context.scalar_uniform_location(location) or { return }
	C.vox_gl_uniform1f(int(handle), x)
}

pub fn (mut context WebGLRenderingContext) uniform2f(location ?&WebGLUniformLocation, x f32, y f32) {
	handle := context.scalar_uniform_location(location) or { return }
	C.vox_gl_uniform2f(int(handle), x, y)
}

pub fn (mut context WebGLRenderingContext) uniform3f(location ?&WebGLUniformLocation, x f32, y f32, z f32) {
	handle := context.scalar_uniform_location(location) or { return }
	C.vox_gl_uniform3f(int(handle), x, y, z)
}

pub fn (mut context WebGLRenderingContext) uniform4f(location ?&WebGLUniformLocation, x f32, y f32, z f32, w f32) {
	handle := context.scalar_uniform_location(location) or { return }
	C.vox_gl_uniform4f(int(handle), x, y, z, w)
}

pub fn (mut context WebGLRenderingContext) uniform1i(location ?&WebGLUniformLocation, x int) {
	handle := context.scalar_uniform_location(location) or { return }
	C.vox_gl_uniform1i(int(handle), x)
}

pub fn (mut context WebGLRenderingContext) uniform2i(location ?&WebGLUniformLocation, x int, y int) {
	handle := context.scalar_uniform_location(location) or { return }
	C.vox_gl_uniform2i(int(handle), x, y)
}

pub fn (mut context WebGLRenderingContext) uniform3i(location ?&WebGLUniformLocation, x int, y int, z int) {
	handle := context.scalar_uniform_location(location) or { return }
	C.vox_gl_uniform3i(int(handle), x, y, z)
}

pub fn (mut context WebGLRenderingContext) uniform4i(location ?&WebGLUniformLocation, x int, y int, z int, w int) {
	handle := context.scalar_uniform_location(location) or { return }
	C.vox_gl_uniform4i(int(handle), x, y, z, w)
}

pub fn (mut context WebGLRenderingContext) vertex_attrib1f(index GLuint, x f32) {
    context.native.make_current()
    C.vox_gl_vertex_attrib1f(index, x)
}

pub fn (mut context WebGLRenderingContext) vertex_attrib2f(index GLuint, x f32, y f32) {
    context.native.make_current()
    C.vox_gl_vertex_attrib2f(index, x, y)
}

pub fn (mut context WebGLRenderingContext) vertex_attrib3f(index GLuint, x f32, y f32, z f32) {
    context.native.make_current()
    C.vox_gl_vertex_attrib3f(index, x, y, z)
}

pub fn (mut context WebGLRenderingContext) vertex_attrib4f(index GLuint, x f32, y f32, z f32, w f32) {
    context.native.make_current()
    C.vox_gl_vertex_attrib4f(index, x, y, z, w)
}

pub fn (mut context WebGLRenderingContext) vertex_attrib1fv(index GLuint, values []f32) {
    // The Source proxy make_current prefix is empty; a short span returns
    // before the actual driver command selects its owner.
    if values.len < 1 {
        context.set_error(invalid_value)
        return
    }
    context.native.make_current()
    C.vox_gl_vertex_attrib1fv(index, values.data)
}

pub fn (mut context WebGLRenderingContext) vertex_attrib2fv(index GLuint, values []f32) {
    // The Source proxy make_current prefix is empty; a short span returns
    // before the actual driver command selects its owner.
    if values.len < 2 {
        context.set_error(invalid_value)
        return
    }
    context.native.make_current()
    C.vox_gl_vertex_attrib2fv(index, values.data)
}

pub fn (mut context WebGLRenderingContext) vertex_attrib3fv(index GLuint, values []f32) {
    // The Source proxy make_current prefix is empty; a short span returns
    // before the actual driver command selects its owner.
    if values.len < 3 {
        context.set_error(invalid_value)
        return
    }
    context.native.make_current()
    C.vox_gl_vertex_attrib3fv(index, values.data)
}

pub fn (mut context WebGLRenderingContext) vertex_attrib4fv(index GLuint, values []f32) {
    // The Source proxy make_current prefix is empty; a short span returns
    // before the actual driver command selects its owner.
    if values.len < 4 {
        context.set_error(invalid_value)
        return
    }
    context.native.make_current()
    C.vox_gl_vertex_attrib_floats(index, values.data)
}

pub fn (mut context WebGLRenderingContext) vertex_attrib_pointer(index GLuint, size int, type_ GLenum, normalized bool, stride int, offset i64) {
    // Source make_current is an empty proxy prefix. Only this retained-slot
    // check returns before the actual driver command selects its owner.
    has_array_buffer := if _ := context.retained_buffer_binding(array_buffer) { true } else { false }
    if !has_array_buffer && offset != 0 {
        context.set_error(invalid_operation)
        return
    }
    context.command('vertex_attrib_pointer', index, size, type_, i64(normalized), stride, offset)
}
