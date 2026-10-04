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
}

fn integer_parameter(value i64) WebGLParameterValue {
	return WebGLParameterValue{ kind: .integer, integer: value }
}

fn number_parameter(value f64) WebGLParameterValue {
	return WebGLParameterValue{ kind: .number, number: value }
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

fn default_webgl_parameters() map[GLenum]WebGLParameterValue {
	mut parameters := map[GLenum]WebGLParameterValue{}
	parameters[blend_dst_alpha] = integer_parameter(gl_zero)
	parameters[blend_dst_rgb] = integer_parameter(gl_zero)
	parameters[blend_equation_alpha] = integer_parameter(func_add)
	parameters[blend_equation_rgb] = integer_parameter(func_add)
	parameters[blend_src_alpha] = integer_parameter(gl_one)
	parameters[blend_src_rgb] = integer_parameter(gl_one)
	parameters[cull_face_mode] = integer_parameter(back)
	parameters[depth_func] = integer_parameter(less)
	parameters[front_face] = integer_parameter(ccw)
	parameters[generate_mipmap_hint] = integer_parameter(dont_care)
	parameters[polygon_offset_factor] = number_parameter(0)
	parameters[polygon_offset_units] = number_parameter(0)
	parameters[sample_coverage_value] = number_parameter(1)
	parameters[sample_coverage_invert] = boolean_parameter(false)
	parameters[stencil_func] = integer_parameter(always)
	parameters[stencil_value_mask] = integer_parameter(-1)
	parameters[stencil_fail] = integer_parameter(keep)
	parameters[stencil_pass_depth_fail] = integer_parameter(keep)
	parameters[stencil_pass_depth_pass] = integer_parameter(keep)
	parameters[stencil_ref] = integer_parameter(0)
	parameters[stencil_writemask] = integer_parameter(-1)
	parameters[stencil_back_func] = integer_parameter(always)
	parameters[stencil_back_value_mask] = integer_parameter(-1)
	parameters[stencil_back_fail] = integer_parameter(keep)
	parameters[stencil_back_pass_depth_fail] = integer_parameter(keep)
	parameters[stencil_back_pass_depth_pass] = integer_parameter(keep)
	parameters[stencil_back_ref] = integer_parameter(0)
	parameters[stencil_back_writemask] = integer_parameter(-1)
	return parameters
}

fn clamp_unit(value f32) f32 {
	return if value < 0 {
		f32(0)
	} else if value > 1 { f32(1) } else { value }
}

fn valid_comparison_function(value GLenum) bool {
	return value in [never, less, equal, lequal, greater, notequal, gequal, always]
}

fn valid_stencil_operation(value GLenum) bool {
	return value in [keep, gl_zero, replace, incr, incr_wrap, decr, decr_wrap, invert]
}

fn (context &WebGLRenderingContext) valid_blend_equation(value GLenum) bool {
	return value in [func_add, func_subtract, func_reverse_subtract]
		|| (value in [gl_min, gl_max]
			&& (context.version == .webgl2 || context.extension_enabled('EXT_blend_minmax')))
}

fn valid_blend_source_factor(value GLenum) bool {
	return value in [gl_zero, gl_one, src_color, one_minus_src_color, src_alpha, one_minus_src_alpha,
		dst_alpha, one_minus_dst_alpha, dst_color, one_minus_dst_color, src_alpha_saturate,
		constant_color, one_minus_constant_color, constant_alpha, one_minus_constant_alpha]
}

fn valid_blend_destination_factor(value GLenum) bool {
	return value != src_alpha_saturate && valid_blend_source_factor(value)
}

fn uses_constant_color(value GLenum) bool {
	return value in [constant_color, one_minus_constant_color]
}

fn uses_constant_alpha(value GLenum) bool {
	return value in [constant_alpha, one_minus_constant_alpha]
}

fn incompatible_constant_blend_factors(source GLenum, destination GLenum) bool {
	return (uses_constant_color(source) && uses_constant_alpha(destination))
		|| (uses_constant_alpha(source) && uses_constant_color(destination))
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

pub fn (context &WebGLRenderingContext) get_error_value() GLenum {
	return context.error_
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
	index := bytes.index(0)
	end := if index < 0 { bytes.len } else { index }
	return bytes[..end].bytestr()
}

pub fn (mut context WebGLRenderingContext) active_texture(texture GLenum) {
	if context.command('active_texture', texture) { context.active_texture_ = texture }
}

pub fn (mut context WebGLRenderingContext) bind_attrib_location(program &WebGLProgram, index GLuint, name string) {
	if !context.owns(&program.object) || name.starts_with('gl_') {
		context.set_error(invalid_operation)
		return
	}
	context.command('bind_attrib_location', program.object.handle_, index, name.len)
	context.native.make_current()
	C.vox_gl_bind_attrib_location(program.object.native_handle_, index, name.str)
	context.native.collect_native_error()
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
	context.native.collect_native_error()
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
	context.native.collect_native_error()
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
	context.native.collect_native_error()
}

pub fn (mut context WebGLRenderingContext) blend_color(red f32, green f32, blue f32, alpha f32) {
	context.blend_color_ = [clamp_unit(red), clamp_unit(green), clamp_unit(blue), clamp_unit(alpha)]!
	context.command('blend_color', i64(red), i64(green), i64(blue), i64(alpha))
    C.vox_gl_blend_color(red,green,blue,alpha)
    context.native.collect_native_error()
}

pub fn (mut context WebGLRenderingContext) blend_equation(mode GLenum) {
	if !context.valid_blend_equation(mode) {
		context.set_error(invalid_enum)
		return
	}
	context.generic_parameters_[blend_equation_rgb] = integer_parameter(mode)
	context.generic_parameters_[blend_equation_alpha] = integer_parameter(mode)
	context.command('blend_equation', mode)
}

pub fn (mut context WebGLRenderingContext) blend_equation_separate(rgb GLenum, alpha GLenum) {
	if !context.valid_blend_equation(rgb) || !context.valid_blend_equation(alpha) {
		context.set_error(invalid_enum)
		return
	}
	context.generic_parameters_[blend_equation_rgb] = integer_parameter(rgb)
	context.generic_parameters_[blend_equation_alpha] = integer_parameter(alpha)
	context.command('blend_equation_separate', rgb, alpha)
}

pub fn (mut context WebGLRenderingContext) blend_func(source GLenum, destination GLenum) {
	if !valid_blend_source_factor(source) || !valid_blend_destination_factor(destination) {
		context.set_error(invalid_enum)
		return
	}
	if incompatible_constant_blend_factors(source, destination) {
		context.set_error(invalid_operation)
		return
	}
	context.generic_parameters_[blend_src_rgb] = integer_parameter(source)
	context.generic_parameters_[blend_src_alpha] = integer_parameter(source)
	context.generic_parameters_[blend_dst_rgb] = integer_parameter(destination)
	context.generic_parameters_[blend_dst_alpha] = integer_parameter(destination)
	context.command('blend_func', source, destination)
}

pub fn (mut context WebGLRenderingContext) blend_func_separate(source_rgb GLenum, destination_rgb GLenum, source_alpha GLenum, destination_alpha GLenum) {
	if !valid_blend_source_factor(source_rgb) || !valid_blend_destination_factor(destination_rgb)
		|| !valid_blend_source_factor(source_alpha)
		|| !valid_blend_destination_factor(destination_alpha) {
		context.set_error(invalid_enum)
		return
	}
	if incompatible_constant_blend_factors(source_rgb, destination_rgb)
		|| incompatible_constant_blend_factors(source_alpha, destination_alpha) {
		context.set_error(invalid_operation)
		return
	}
	context.generic_parameters_[blend_src_rgb] = integer_parameter(source_rgb)
	context.generic_parameters_[blend_dst_rgb] = integer_parameter(destination_rgb)
	context.generic_parameters_[blend_src_alpha] = integer_parameter(source_alpha)
	context.generic_parameters_[blend_dst_alpha] = integer_parameter(destination_alpha)
	context.command('blend_func_separate', source_rgb, destination_rgb, source_alpha, destination_alpha)
}

pub fn (mut context WebGLRenderingContext) check_framebuffer_status(target GLenum) GLenum {
	context.command('check_framebuffer_status', target)
	result := GLenum(C.vox_gl_framebuffer_status(target))
	context.native.collect_native_error()
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
	if mode !in [front, back, front_and_back] {
		context.set_error(invalid_enum)
		return
	}
	context.generic_parameters_[cull_face_mode] = integer_parameter(mode)
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
		handle := handle_result.value
		context.framebuffers.delete(handle)
		context.command('delete_framebuffer', handle)
		C.vox_gl_delete_object(1, value.object.native_handle_)
		context.native.collect_native_error()
		if bound := context.bound_framebuffer_object {
			if bound == value {
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
		handle := handle_result.value
		context.renderbuffers.delete(handle)
		context.command('delete_renderbuffer', handle)
		C.vox_gl_delete_object(2, value.object.native_handle_)
		context.native.collect_native_error()
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
		handle := handle_result.value
		context.textures.delete(handle)
		context.command('delete_texture', handle)
		C.vox_gl_delete_object(3, value.object.native_handle_)
		context.native.collect_native_error()
		for target, bound in context.bound_texture_objects {
			if bound == value {
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
		handle := handle_result.value
		context.shaders.delete(handle)
		context.native.make_current()
		C.vox_gl_delete_shader(value.object.native_handle_)
		context.native.collect_native_error()
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
		handle := handle_result.value
		context.programs.delete(handle)
		context.native.make_current()
		C.vox_gl_delete_program(value.object.native_handle_)
		context.native.collect_native_error()
		if current := context.current_program {
			if current.object.handle_ == handle {
				context.current_program = none
			}
		}
		context.command('delete_program', handle)
	}
}

pub fn (mut context WebGLRenderingContext) depth_func(function GLenum) {
	if !valid_comparison_function(function) {
		context.set_error(invalid_enum)
		return
	}
	context.generic_parameters_[depth_func] = integer_parameter(function)
	context.command('depth_func', function)
}

pub fn (mut context WebGLRenderingContext) depth_range(near f64, far f64) {
	context.depth_range_ = [
		if near < 0 {
			f64(0)
		} else if near > 1 { f64(1) } else { near },
		if far < 0 {
			f64(0)
		} else if far > 1 { f64(1) } else { far },
	]!
	context.command('depth_range', i64(context.depth_range_[0]), i64(context.depth_range_[1]))
    C.vox_gl_depth_range(f32(near),f32(far))
    context.native.collect_native_error()
}

pub fn (mut context WebGLRenderingContext) finish() {
	context.command('finish')
}

pub fn (mut context WebGLRenderingContext) flush() {
	context.command('flush')
}

pub fn (mut context WebGLRenderingContext) front_face(mode GLenum) {
	if mode !in [cw, ccw] {
		context.set_error(invalid_enum)
		return
	}
	context.generic_parameters_[front_face] = integer_parameter(mode)
	context.command('front_face', mode)
}

pub fn (mut context WebGLRenderingContext) generate_mipmap(target GLenum) {
	context.command('generate_mipmap', target)
}

pub fn (mut context WebGLRenderingContext) hint(target GLenum, mode GLenum) {
	valid_target := target == generate_mipmap_hint
		|| (target == fragment_shader_derivative_hint
			&& (context.version == .webgl2 || context.extension_enabled('OES_standard_derivatives')))
	if !valid_target || mode !in [dont_care, fastest, nicest] {
		context.set_error(invalid_enum)
		return
	}
	context.generic_parameters_[target] = integer_parameter(mode)
	context.command('hint', target, mode)
}

pub fn (mut context WebGLRenderingContext) framebuffer_renderbuffer(target GLenum, attachment GLenum, renderbuffer_target GLenum, object ?&WebGLRenderbuffer) {
	if !is_valid_framebuffer_binding_target(context.version, target)
		|| !is_valid_framebuffer_attachment(context.version, context.extension_enabled('WEBGL_draw_buffers'), attachment)
		|| renderbuffer_target != renderbuffer {
		context.set_error(invalid_enum)
		return
	}
	if context.bound_framebuffer == 0 {
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
	if framebuffer_object := context.bound_framebuffer_object {
		mut mutable := unsafe { &WebGLFramebuffer(framebuffer_object) }
		mutable.set_renderbuffer_attachment(attachment, object)
	}
	context.command('framebuffer_renderbuffer', target, attachment, renderbuffer_target, handle)
	C.vox_gl_framebuffer_renderbuffer(target, attachment, renderbuffer_target, if value := object { value.object.native_handle_ } else { 0 })
	context.native.collect_native_error()
}

pub fn (mut context WebGLRenderingContext) framebuffer_texture2d(target GLenum, attachment GLenum, texture_target GLenum, object ?&WebGLTexture, level int) {
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
	if context.bound_framebuffer == 0 {
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
	if framebuffer_object := context.bound_framebuffer_object {
		mut mutable := unsafe { &WebGLFramebuffer(framebuffer_object) }
		mutable.set_texture_attachment(attachment, object, texture_target, level)
	}
	context.command('framebuffer_texture2d', target, attachment, texture_target, handle, level)
	C.vox_gl_framebuffer_texture(target, attachment, texture_target, if value := object { value.object.native_handle_ } else { 0 }, level)
	context.native.collect_native_error()
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
				}
			}
			if renderbuffer_object := framebuffer_attachment.renderbuffer {
				return WebGLParameterValue{
					kind: .object
					object: renderbuffer_object.object.handle_
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
	context.native.make_current()
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
	context.native.make_current()
	if !context.owns(&program.object) {
		context.set_error(invalid_operation)
		return none
	}
	return context.native.native_program_log(program.object.native_handle_)
}

pub fn (mut context WebGLRenderingContext) get_program_parameter(program &WebGLProgram, pname GLenum) WebGLParameterValue {
	context.native.make_current()
	if !context.owns(&program.object) {
		context.set_error(invalid_operation)
		return WebGLParameterValue{}
	}
	result := context.native.native_program_parameter(program.object.native_handle_, pname)
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
	context.native.make_current()
	if !context.owns(&shader.object) {
		context.set_error(invalid_operation)
		return WebGLParameterValue{}
	}
	result := context.native.native_shader_parameter(shader.object.native_handle_, pname)
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
	mut range := [0, 0]!
	mut bits := 0
	C.vox_gl_shader_precision(shader, precision, &range[0], &bits)
	context.native.collect_native_error()
	return WebGLShaderPrecisionFormat.create(range[0], range[1], bits)
}

pub fn (mut context WebGLRenderingContext) get_buffer_parameter(target GLenum, pname GLenum) WebGLParameterValue {
	context.native.make_current()
    if pname !in [buffer_size, buffer_usage] { context.set_error(invalid_enum); return WebGLParameterValue{} }
    result := C.vox_gl_buffer_parameter(target, pname)
    context.native.collect_native_error()
    return integer_parameter(result)
}

pub fn (mut context WebGLRenderingContext) get_parameter(pname GLenum) WebGLParameterValue {
	context.native.make_current()
	if (pname == fragment_shader_derivative_hint && context.version != .webgl2 && !context.extension_enabled('OES_standard_derivatives'))
		|| (pname == GLenum(0x8cdf) && context.version != .webgl2 && !context.extension_enabled('WEBGL_draw_buffers'))
		|| (pname == GLenum(0x8824) && context.version != .webgl2)
		|| (pname == GLenum(0x84ff) && !context.extension_enabled('EXT_texture_filter_anisotropic')) {
		context.set_error(invalid_enum)
		return WebGLParameterValue{}
	}
	shape := C.vox_gl_parameter_shape(pname,if context.version == .webgl2 {3} else {2})
	if shape != 0 {
		context.native.make_current()
		if shape == 51 { return WebGLParameterValue{kind:.string_,text:native_gl_string(pname)} }
		mut values := [f64(0),0,0,0]!
		C.vox_gl_parameter(pname,shape,&values[0])
		context.native.collect_native_error()
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
		return WebGLParameterValue{kind:.object,object:array.object.handle_}
	}
 match pname {
  array_buffer_binding,element_array_buffer_binding {
   target:=if pname==array_buffer_binding {array_buffer} else {element_array_buffer}
   handle:=context.bound_buffers[target] or {return WebGLParameterValue{}}
   return WebGLParameterValue{kind:.object,object:handle,buffer:context.retained_buffer_binding(target)}
  }
  framebuffer_binding {return if context.bound_framebuffer==0 {WebGLParameterValue{}} else {WebGLParameterValue{kind:.object,object:context.bound_framebuffer,framebuffer:context.bound_framebuffer_object}}}
  renderbuffer_binding {return if context.bound_renderbuffer==0 {WebGLParameterValue{}} else {WebGLParameterValue{kind:.object,object:context.bound_renderbuffer,renderbuffer:context.bound_renderbuffer_object}}}
  current_program {program:=context.current_program or {return WebGLParameterValue{}};return WebGLParameterValue{kind:.object,object:program.object.handle_}}
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
   vertex_array_binding {array:=context.current_vertex_array or {return WebGLParameterValue{}};return WebGLParameterValue{kind:.object,object:array.object.handle_}}
   sampler_binding {
    mut handle:=0
    C.vox_gl_int_parameter(pname,&handle)
    context.native.collect_native_error()
    logical:=context.allocate_handle()
    sampler:=&WebGLSampler{object:WebGLObject{...new_object(context.identity(),context.context_generation_,logical),native_handle_:GLuint(handle)}}
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
	context.native.make_current()
 if pname !in [GLenum(0x8d42),0x8d43,0x8d44,0x8d50,0x8d51,0x8d52,0x8d53,0x8d54,0x8cab,0x8d55] {
  context.set_error(invalid_enum); return WebGLParameterValue{}
 }
 result:=C.vox_gl_renderbuffer_parameter(target,pname)
 context.native.collect_native_error()
 return integer_parameter(result)
}

pub fn (mut context WebGLRenderingContext) get_tex_parameter(target GLenum, pname GLenum) WebGLParameterValue {
	context.native.make_current()
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
 result:=if float_result {f64(C.vox_gl_tex_float_parameter(target,queried_name))} else {f64(C.vox_gl_tex_parameter(target,queried_name))}
 context.native.collect_native_error()
 return if boolean_result {WebGLParameterValue{kind:.boolean,boolean:result==1}} else {integer_parameter(i64(result))}
}

pub fn (context &WebGLRenderingContext) get_uniform(_ &WebGLProgram, location ?&WebGLUniformLocation) WebGLParameterValue {
	value := location or { return WebGLParameterValue{} }
	values := context.uniform_values_[value.handle_] or { return WebGLParameterValue{} }
	return WebGLParameterValue{ kind: .numbers, numbers: values.map(f64(it)) }
}

pub fn (mut context WebGLRenderingContext) get_active_attrib(program &WebGLProgram, index GLuint) ?WebGLActiveInfo {
	context.native.make_current()
	if !context.owns(&program.object) { context.set_error(invalid_operation); return none }
	return context.native.native_active_info(program.object.native_handle_, index, false)
}

pub fn (mut context WebGLRenderingContext) get_active_uniform(program &WebGLProgram, index GLuint) ?WebGLActiveInfo {
	context.native.make_current()
	if !context.owns(&program.object) { context.set_error(invalid_operation); return none }
	return context.native.native_active_info(program.object.native_handle_, index, true)
}

pub fn (mut context WebGLRenderingContext) get_attrib_location(program &WebGLProgram, name string) int {
	context.native.make_current()
	if !context.owns(&program.object) { context.set_error(invalid_operation); return -1 }
	result := C.vox_gl_attrib_location(program.object.native_handle_, name.str)
	context.native.collect_native_error()
	return result
}

pub fn (mut context WebGLRenderingContext) get_vertex_attrib(index GLuint, pname GLenum) WebGLParameterValue {
    context.native.make_current()
    if pname == current_vertex_attrib {
        mut values := []f32{len:4}
        C.vox_gl_vertex_attrib_float_parameter(index,values.data)
        context.native.collect_native_error()
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
    value := C.vox_gl_vertex_attrib_parameter(index,pname)
    context.native.collect_native_error()
    if pname == vertex_attrib_array_buffer_binding {
        handle := context.allocate_handle()
        buffer := &WebGLBuffer{object: WebGLObject{...new_object(context.identity(),context.context_generation_,handle),native_handle_:GLuint(value)}}
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
    context.native.collect_native_error()
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
	context.native.make_current()
	object := value or { return false }
	context.object_handle_for_query(&object.object) or { return false }
	return C.vox_gl_is_object(9,object.object.native_handle_) == 1
}

pub fn (mut context WebGLRenderingContext) is_program(value ?&WebGLProgram) bool {
	context.native.make_current()
	object := value or { return false }
	context.object_handle_for_query(&object.object) or { return false }
	return C.vox_gl_is_object(10,object.object.native_handle_) == 1
}

pub fn (mut context WebGLRenderingContext) line_width(width f32) {
	if width <= 0 {
		context.set_error(invalid_value)
		return
	}
	context.line_width_ = width
	context.command('line_width', i64(width))
    C.vox_gl_line_width(width)
    context.native.collect_native_error()
}

pub fn (mut context WebGLRenderingContext) polygon_offset(factor f32, units f32) {
	context.generic_parameters_[polygon_offset_factor] = number_parameter(factor)
	context.generic_parameters_[polygon_offset_units] = number_parameter(units)
	context.command('polygon_offset', i64(factor), i64(units))
    C.vox_gl_polygon_offset(factor,units)
    context.native.collect_native_error()
}

pub fn (mut context WebGLRenderingContext) renderbuffer_storage(target GLenum, internal_format GLenum, width int, height int) {
	context.native.make_current()
	// Source GL_DEPTH_STENCIL is stored as GL_DEPTH24_STENCIL8.
	format := if internal_format == GLenum(0x84f9) { GLenum(0x88f0) } else { internal_format }
	context.command('renderbuffer_storage', target, format, width, height)
	C.vox_gl_renderbuffer_storage(target, format, width, height)
	context.native.collect_native_error()
}

pub fn (mut context WebGLRenderingContext) sample_coverage(value f32, invert bool) {
	context.generic_parameters_[sample_coverage_value] = number_parameter(clamp_unit(value))
	context.generic_parameters_[sample_coverage_invert] = boolean_parameter(invert)
	context.command('sample_coverage', i64(value), i64(invert))
    C.vox_gl_sample_coverage(value,int(invert))
    context.native.collect_native_error()
}

pub fn (mut context WebGLRenderingContext) stencil_func(function GLenum, reference int, mask GLuint) {
	if !valid_comparison_function(function) {
		context.set_error(invalid_enum)
		return
	}
	context.generic_parameters_[stencil_func] = integer_parameter(function)
	context.generic_parameters_[stencil_back_func] = integer_parameter(function)
	context.generic_parameters_[stencil_ref] = integer_parameter(reference)
	context.generic_parameters_[stencil_back_ref] = integer_parameter(reference)
	context.generic_parameters_[stencil_value_mask] = integer_parameter(i64(i32(mask)))
	context.generic_parameters_[stencil_back_value_mask] = integer_parameter(i64(i32(mask)))
	context.command('stencil_func', function, reference, mask)
}

pub fn (mut context WebGLRenderingContext) stencil_func_separate(face GLenum, function GLenum, reference int, mask GLuint) {
	if face !in [front, back, front_and_back] || !valid_comparison_function(function) {
		context.set_error(invalid_enum)
		return
	}
	if face in [front, front_and_back] {
		context.generic_parameters_[stencil_func] = integer_parameter(function)
		context.generic_parameters_[stencil_ref] = integer_parameter(reference)
		context.generic_parameters_[stencil_value_mask] = integer_parameter(i64(i32(mask)))
	}
	if face in [back, front_and_back] {
		context.generic_parameters_[stencil_back_func] = integer_parameter(function)
		context.generic_parameters_[stencil_back_ref] = integer_parameter(reference)
		context.generic_parameters_[stencil_back_value_mask] = integer_parameter(i64(i32(mask)))
	}
	context.command('stencil_func_separate', face, function, reference, mask)
}

pub fn (mut context WebGLRenderingContext) stencil_mask(mask GLuint) {
	context.generic_parameters_[stencil_writemask] = integer_parameter(i64(i32(mask)))
	context.generic_parameters_[stencil_back_writemask] = integer_parameter(i64(i32(mask)))
	context.command('stencil_mask', mask)
}

pub fn (mut context WebGLRenderingContext) stencil_mask_separate(face GLenum, mask GLuint) {
	if face !in [front, back, front_and_back] {
		context.set_error(invalid_enum)
		return
	}
	if face in [front, front_and_back] {
		context.generic_parameters_[stencil_writemask] = integer_parameter(i64(i32(mask)))
	}
	if face in [back, front_and_back] {
		context.generic_parameters_[stencil_back_writemask] = integer_parameter(i64(i32(mask)))
	}
	context.command('stencil_mask_separate', face, mask)
}

pub fn (mut context WebGLRenderingContext) stencil_op(fail GLenum, depth_fail GLenum, pass GLenum) {
	if !valid_stencil_operation(fail) || !valid_stencil_operation(depth_fail)
		|| !valid_stencil_operation(pass) {
		context.set_error(invalid_enum)
		return
	}
	context.generic_parameters_[stencil_fail] = integer_parameter(fail)
	context.generic_parameters_[stencil_back_fail] = integer_parameter(fail)
	context.generic_parameters_[stencil_pass_depth_fail] = integer_parameter(depth_fail)
	context.generic_parameters_[stencil_back_pass_depth_fail] = integer_parameter(depth_fail)
	context.generic_parameters_[stencil_pass_depth_pass] = integer_parameter(pass)
	context.generic_parameters_[stencil_back_pass_depth_pass] = integer_parameter(pass)
	context.command('stencil_op', fail, depth_fail, pass)
}

pub fn (mut context WebGLRenderingContext) stencil_op_separate(face GLenum, fail GLenum, depth_fail GLenum, pass GLenum) {
	if face !in [front, back, front_and_back] || !valid_stencil_operation(fail)
		|| !valid_stencil_operation(depth_fail) || !valid_stencil_operation(pass) {
		context.set_error(invalid_enum)
		return
	}
	if face in [front, front_and_back] {
		context.generic_parameters_[stencil_fail] = integer_parameter(fail)
		context.generic_parameters_[stencil_pass_depth_fail] = integer_parameter(depth_fail)
		context.generic_parameters_[stencil_pass_depth_pass] = integer_parameter(pass)
	}
	if face in [back, front_and_back] {
		context.generic_parameters_[stencil_back_fail] = integer_parameter(fail)
		context.generic_parameters_[stencil_back_pass_depth_fail] = integer_parameter(depth_fail)
		context.generic_parameters_[stencil_back_pass_depth_pass] = integer_parameter(pass)
	}
	context.command('stencil_op_separate', face, fail, depth_fail, pass)
}

pub fn (mut context WebGLRenderingContext) tex_parameteri(target GLenum, pname GLenum, parameter int) {
	context.native.make_current()
	C.vox_gl_tex_parameteri(target, pname, parameter)
	context.native.collect_native_error()
}

pub fn (mut context WebGLRenderingContext) tex_parameterf(target GLenum, pname GLenum, parameter f32) {
	context.native.make_current()
	C.vox_gl_tex_parameterf(target, pname, parameter)
	context.native.collect_native_error()
}

fn (mut context WebGLRenderingContext) uniform_floats(location ?&WebGLUniformLocation, values []f32, width int) {
 value := location or { return }
 value.handle(context.current_program) or { context.set_error(invalid_operation); return }

 if values.len % width != 0 { context.set_error(invalid_value); return }
 context.native.make_current()
 C.vox_gl_uniform_floats(int(value.handle_), width, values.len / width, values.data)
 error_value := GLenum(C.vox_gl_get_error())
 if error_value != no_error { context.native.set_pending_local_error(error_value); return }
 context.uniform_values_[value.handle_] = values.clone()
}

fn (mut context WebGLRenderingContext) uniform_ints(location ?&WebGLUniformLocation, values []int, width int) {
 value := location or { return }
 value.handle(context.current_program) or { context.set_error(invalid_operation); return }

 if values.len % width != 0 { context.set_error(invalid_value); return }
 context.native.make_current()
 C.vox_gl_uniform_ints(int(value.handle_), width, values.len / width, values.data)
 error_value := GLenum(C.vox_gl_get_error())
 if error_value != no_error { context.native.set_pending_local_error(error_value); return }
 context.uniform_values_[value.handle_] = values.map(f32(it))
}

fn (mut context WebGLRenderingContext) uniform_uints(location ?&WebGLUniformLocation, values []u32, width int) {
 value := location or { return }
 value.handle(context.current_program) or { context.set_error(invalid_operation); return }
 if !context.require_webgl2() { return }
 if values.len % width != 0 { context.set_error(invalid_value); return }
 context.native.make_current()
 C.vox_gl_uniform_uints(int(value.handle_), width, values.len / width, values.data)
 error_value := GLenum(C.vox_gl_get_error())
 if error_value != no_error { context.native.set_pending_local_error(error_value); return }
 context.uniform_values_[value.handle_] = values.map(f32(it))
}

pub fn (mut context WebGLRenderingContext) uniform1f(location ?&WebGLUniformLocation, x f32) {
 context.uniform_floats(location, [x], 1)
}

pub fn (mut context WebGLRenderingContext) uniform2f(location ?&WebGLUniformLocation, x f32, y f32) {
 context.uniform_floats(location, [x, y], 2)
}

pub fn (mut context WebGLRenderingContext) uniform3f(location ?&WebGLUniformLocation, x f32, y f32, z f32) {
 context.uniform_floats(location, [x, y, z], 3)
}

pub fn (mut context WebGLRenderingContext) uniform4f(location ?&WebGLUniformLocation, x f32, y f32, z f32, w f32) {
 context.uniform_floats(location, [x, y, z, w], 4)
}

pub fn (mut context WebGLRenderingContext) uniform1i(location ?&WebGLUniformLocation, x int) {
 context.uniform_ints(location, [x], 1)
}

pub fn (mut context WebGLRenderingContext) uniform2i(location ?&WebGLUniformLocation, x int, y int) {
 context.uniform_ints(location, [x, y], 2)
}

pub fn (mut context WebGLRenderingContext) uniform3i(location ?&WebGLUniformLocation, x int, y int, z int) {
 context.uniform_ints(location, [x, y, z], 3)
}

pub fn (mut context WebGLRenderingContext) uniform4i(location ?&WebGLUniformLocation, x int, y int, z int, w int) {
 context.uniform_ints(location, [x, y, z, w], 4)
}

pub fn (mut context WebGLRenderingContext) vertex_attrib1f(index GLuint, x f32) {
	context.vertex_attrib_values_[index] = [x, f32(0), 0, 1]
    context.native.make_current()
    C.vox_gl_vertex_attrib_floats(index, context.vertex_attrib_values_[index].data)
    context.native.collect_native_error()
}

pub fn (mut context WebGLRenderingContext) vertex_attrib2f(index GLuint, x f32, y f32) {
	context.vertex_attrib_values_[index] = [x, y, f32(0), 1]
    context.native.make_current()
    C.vox_gl_vertex_attrib_floats(index, context.vertex_attrib_values_[index].data)
    context.native.collect_native_error()
}

pub fn (mut context WebGLRenderingContext) vertex_attrib3f(index GLuint, x f32, y f32, z f32) {
	context.vertex_attrib_values_[index] = [x, y, z, f32(1)]
    context.native.make_current()
    C.vox_gl_vertex_attrib_floats(index, context.vertex_attrib_values_[index].data)
    context.native.collect_native_error()
}

pub fn (mut context WebGLRenderingContext) vertex_attrib4f(index GLuint, x f32, y f32, z f32, w f32) {
	context.vertex_attrib_values_[index] = [x, y, z, w]
    context.native.make_current()
    C.vox_gl_vertex_attrib_floats(index, context.vertex_attrib_values_[index].data)
    context.native.collect_native_error()
}

pub fn (mut context WebGLRenderingContext) vertex_attrib1fv(index GLuint, values []f32) {
	if values.len >= 1 {
		context.vertex_attrib1f(index, values[0])
	} else {
		context.set_error(invalid_value)
	}
}

pub fn (mut context WebGLRenderingContext) vertex_attrib2fv(index GLuint, values []f32) {
	if values.len >= 2 {
		context.vertex_attrib2f(index, values[0], values[1])
	} else {
		context.set_error(invalid_value)
	}
}

pub fn (mut context WebGLRenderingContext) vertex_attrib3fv(index GLuint, values []f32) {
	if values.len >= 3 {
		context.vertex_attrib3f(index, values[0], values[1], values[2])
	} else {
		context.set_error(invalid_value)
	}
}

pub fn (mut context WebGLRenderingContext) vertex_attrib4fv(index GLuint, values []f32) {
	if values.len >= 4 {
		context.vertex_attrib4f(index, values[0], values[1], values[2], values[3])
	} else {
		context.set_error(invalid_value)
	}
}

pub fn (mut context WebGLRenderingContext) vertex_attrib_pointer(index GLuint, size int, type_ GLenum, normalized bool, stride int, offset i64) {
	if size < 1 || size > 4 || stride < 0 || offset < 0 {
		context.set_error(invalid_value)
		return
	}
	buffer_handle := context.bound_buffers[array_buffer] or {
		context.set_error(invalid_operation)
		return
	}
	context.vertex_attrib_states_[index] = VertexAttribState{
		buffer_handle: buffer_handle
		size: size
		type_: type_
		normalized: normalized
		stride: stride
		offset: offset
	}
	context.command('vertex_attrib_pointer', index, size, type_, i64(normalized), stride, offset)
}
