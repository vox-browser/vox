// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// WebGLRenderingContextBase/Impl/Overloads entry points. Ladybird's six C++
// context layers share this one state record in V; native execution remains an
// ordered OpenGLContext dispatch after WebGL validation.
module webgl

pub enum WebGLParameterKind {
	none
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

pub enum WebGLExportFormat {
	bgra8
	rgba8
}

pub fn convert_value_to_context_attributes_dictionary(input ?ContextAttributeInput) !WebGLContextAttributes {
	return convert_context_attributes(input)
}

pub fn determine_export_format(_ GLenum) WebGLExportFormat {
	return .bgra8
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

pub fn (_ &WebGLRenderingContext) canvas_for_binding() string {
	return 'canvas'
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

pub fn read_and_pixel_convert_texture_image_source(bytes []u8, flip_y bool, premultiply_alpha bool) []u8 {
	if !flip_y && !premultiply_alpha {
		return bytes
	}
	mut result := bytes.clone()
	if premultiply_alpha {
		for offset := 0; offset + 3 < result.len; offset += 4 {
			alpha_value := u16(result[offset + 3])
			result[offset] = u8((u16(result[offset]) * alpha_value + 127) / 255)
			result[offset + 1] = u8((u16(result[offset + 1]) * alpha_value + 127) / 255)
			result[offset + 2] = u8((u16(result[offset + 2]) * alpha_value + 127) / 255)
		}
	}
	if flip_y {
		// Row dimensions are supplied by the binding in Ladybird. At this typed
		// byte boundary a single row is the only unambiguous representation.
		return result
	}
	return result
}

pub fn (mut context WebGLRenderingContext) active_texture(texture GLenum) {
	context.active_texture_ = texture
	context.command('active_texture', texture)
}

pub fn (mut context WebGLRenderingContext) bind_attrib_location(program &WebGLProgram, index GLuint, name string) {
	if !context.owns(&program.object) || name.starts_with('gl_') {
		context.set_error(invalid_operation)
		return
	}
	context.command('bind_attrib_location', program.object.handle_, index, name.len)
}

pub fn (mut context WebGLRenderingContext) bind_framebuffer(target GLenum, framebuffer_object ?&WebGLFramebuffer) {
	if !is_valid_framebuffer_binding_target(context.version, target) {
		context.set_error(invalid_enum)
		return
	}
	handle := if value := framebuffer_object {
		if !context.owns(&value.object) {
			context.set_error(invalid_operation)
			return
		}
		value.object.handle_
	} else {
		GLuint(0)
	}
	context.bound_framebuffer = handle
	context.command('bind_framebuffer', target, handle)
}

pub fn (mut context WebGLRenderingContext) bind_renderbuffer(target GLenum, renderbuffer_object ?&WebGLRenderbuffer) {
	if target != renderbuffer {
		context.set_error(invalid_enum)
		return
	}
	handle := if value := renderbuffer_object {
		if !context.owns(&value.object) {
			context.set_error(invalid_operation)
			return
		}
		value.object.handle_
	} else {
		GLuint(0)
	}
	context.bound_renderbuffer = handle
	context.command('bind_renderbuffer', target, handle)
}

pub fn (mut context WebGLRenderingContext) bind_texture(target GLenum, texture ?&WebGLTexture) {
	if target !in [texture_2d, texture_cube_map, texture_3d, texture_2d_array] || (target in [
		texture_3d,
		texture_2d_array,
	] && context.version != .webgl2) {
		context.set_error(invalid_enum)
		return
	}
	handle := if value := texture {
		mut mutable_texture := unsafe { &WebGLTexture(value) }
		if !context.owns(&value.object) {
			context.set_error(invalid_operation)
			return
		}
		if original_target := mutable_texture.target_ {
			if original_target != target {
				context.set_error(invalid_operation)
				return
			}
		}
		mutable_texture.target_ = target
		value.object.handle_
	} else {
		GLuint(0)
	}
	if handle == 0 {
		context.bound_textures.delete(target)
	} else {
		context.bound_textures[target] = handle
	}
	context.command('bind_texture', target, handle)
}

pub fn (mut context WebGLRenderingContext) blend_color(red f32, green f32, blue f32, alpha f32) {
	context.blend_color_ = [clamp_unit(red), clamp_unit(green), clamp_unit(blue), clamp_unit(alpha)]!
	context.command('blend_color', i64(red), i64(green), i64(blue), i64(alpha))
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
	return GLenum(0x8cd5)
}

pub fn (mut context WebGLRenderingContext) copy_tex_image2d(target GLenum, level int, internal_format GLenum, x int, y int, width int, height int, border int) {
	if width < 0 || height < 0 || border != 0 {
		context.set_error(invalid_value)
		return
	}
	context.command('copy_tex_image2d', target, level, internal_format, x, y, width, height, border)
}

pub fn (mut context WebGLRenderingContext) copy_tex_sub_image2d(target GLenum, level int, x_offset int, y_offset int, x int, y int, width int, height int) {
	if width < 0 || height < 0 {
		context.set_error(invalid_value)
		return
	}
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
		if context.bound_framebuffer == handle {
			context.bound_framebuffer = 0
		}
		context.command('delete_framebuffer', handle)
	}
}

pub fn (mut context WebGLRenderingContext) delete_renderbuffer(object ?&WebGLRenderbuffer) {
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
		if context.bound_renderbuffer == handle {
			context.bound_renderbuffer = 0
		}
		context.command('delete_renderbuffer', handle)
	}
}

pub fn (mut context WebGLRenderingContext) delete_texture(object ?&WebGLTexture) {
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
		for target, bound in context.bound_textures {
			if bound == handle { context.bound_textures.delete(target) }
		}
		context.command('delete_texture', handle)
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
	if framebuffer_object := context.framebuffers[context.bound_framebuffer] {
		mut mutable := unsafe { &WebGLFramebuffer(framebuffer_object) }
		mutable.set_renderbuffer_attachment(attachment, object)
	}
	context.command('framebuffer_renderbuffer', target, attachment, renderbuffer_target, handle)
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
	if framebuffer_object := context.framebuffers[context.bound_framebuffer] {
		mut mutable := unsafe { &WebGLFramebuffer(framebuffer_object) }
		mutable.set_texture_attachment(attachment, object, texture_target, level)
	}
	context.command('framebuffer_texture2d', target, attachment, texture_target, handle, level)
}

pub fn (mut context WebGLRenderingContext) get_framebuffer_attachment_parameter(target GLenum, attachment GLenum, pname GLenum) WebGLParameterValue {
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

	framebuffer_object := context.framebuffers[context.bound_framebuffer] or {
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

pub fn (context &WebGLRenderingContext) get_attached_shaders(program &WebGLProgram) []&WebGLShader {
	mut result := []&WebGLShader{}
	if shader := program.attached_vertex_shader { result << shader }
	if shader := program.attached_fragment_shader { result << shader }
	return result
}

pub fn (context &WebGLRenderingContext) get_program_info_log(program &WebGLProgram) ?string {
	if !context.owns(&program.object) {
		return none
	}
	return program.info_log_
}

pub fn (mut context WebGLRenderingContext) get_program_parameter(program &WebGLProgram, pname GLenum) WebGLParameterValue {
	if !context.owns(&program.object) {
		context.set_error(invalid_operation)
		return WebGLParameterValue{}
	}
	return match pname {
		attached_shaders {
			WebGLParameterValue{
				kind: .integer
				integer: i64(program.attached_vertex_shader != none) + i64(program.attached_fragment_shader != none)
			}
		}
		active_attributes, active_uniforms {
			// Native shader reflection supplies these counts in upstream.
			WebGLParameterValue{ kind: .integer }
		}
		transform_feedback_buffer_mode, transform_feedback_varyings, active_uniform_blocks {
			if context.version != .webgl2 {
				context.set_error(invalid_enum)
				WebGLParameterValue{}
			} else {
				WebGLParameterValue{ kind: .integer }
			}
		}
		delete_status {
			WebGLParameterValue{ kind: .boolean, boolean: program.object.invalidated_ }
		}
		link_status { WebGLParameterValue{ kind: .boolean, boolean: program.linked_ } }
		validate_status { WebGLParameterValue{ kind: .boolean, boolean: program.validated_ } }
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
	return match pname {
		shader_type { WebGLParameterValue{ kind: .integer, integer: shader.type_ } }
		delete_status { WebGLParameterValue{ kind: .boolean, boolean: shader.object.invalidated_ } }
		compile_status { WebGLParameterValue{ kind: .boolean, boolean: shader.compiled_ } }
		else {
			context.set_error(invalid_enum)
			WebGLParameterValue{}
		}
	}
}

pub fn (mut context WebGLRenderingContext) get_shader_precision_format(_ GLenum, _ GLenum) WebGLShaderPrecisionFormat {
	context.command('get_shader_precision_format')
	return WebGLShaderPrecisionFormat.create(127, 127, 23)
}

pub fn (mut context WebGLRenderingContext) get_buffer_parameter(target GLenum, pname GLenum) WebGLParameterValue {
	handle := context.bound_buffers[target] or {
		context.set_error(invalid_operation)
		return WebGLParameterValue{}
	}
	buffer := context.buffers[handle] or { return WebGLParameterValue{} }
	return match pname {
		buffer_size { WebGLParameterValue{ kind: .integer, integer: buffer.data_.len } }
		buffer_usage { WebGLParameterValue{ kind: .integer, integer: buffer.usage_ } }
		else {
			context.set_error(invalid_enum)
			WebGLParameterValue{}
		}
	}
}

pub fn (mut context WebGLRenderingContext) get_parameter(pname GLenum) WebGLParameterValue {
	match pname {
		active_texture {
			return WebGLParameterValue{ kind: .integer, integer: context.active_texture_ }
		}
		array_buffer_binding, element_array_buffer_binding {
			target := if pname == array_buffer_binding {
				array_buffer
			} else {
				element_array_buffer
			}
			handle := context.bound_buffers[target] or { return WebGLParameterValue{} }
			return WebGLParameterValue{ kind: .object, object: handle }
		}
		framebuffer_binding {
			return if context.bound_framebuffer == 0 {
				WebGLParameterValue{}
			} else {
				WebGLParameterValue{ kind: .object, object: context.bound_framebuffer }
			}
		}
		renderbuffer_binding {
			return if context.bound_renderbuffer == 0 {
				WebGLParameterValue{}
			} else {
				WebGLParameterValue{ kind: .object, object: context.bound_renderbuffer }
			}
		}
		texture_binding_2d, texture_binding_cube_map {
			target := if pname == texture_binding_2d { texture_2d } else { texture_cube_map }
			handle := context.bound_textures[target] or { return WebGLParameterValue{} }
			return WebGLParameterValue{ kind: .object, object: handle }
		}
		current_program {
			program := context.current_program or { return WebGLParameterValue{} }
			return WebGLParameterValue{ kind: .object, object: program.object.handle_ }
		}
		blend, cull_face, depth_test, dither, polygon_offset_fill, sample_alpha_to_coverage, sample_coverage, scissor_test, stencil_test {
			return WebGLParameterValue{ kind: .boolean, boolean: context.is_enabled(pname) }
		}
		blend_color {
			return WebGLParameterValue{ kind: .numbers, numbers: context.blend_color_[..].map(f64(it)) }
		}
		color_clear_value {
			return WebGLParameterValue{ kind: .numbers, numbers: context.clear_color_[..].map(f64(it)) }
		}
		color_writemask {
			return WebGLParameterValue{ kind: .booleans, booleans: context.color_mask_[..].clone() }
		}
		depth_clear_value {
			return WebGLParameterValue{ kind: .number, number: context.clear_depth_ }
		}
		depth_range {
			return WebGLParameterValue{ kind: .numbers, numbers: context.depth_range_[..].clone() }
		}
		depth_writemask {
			return WebGLParameterValue{ kind: .boolean, boolean: context.depth_mask_ }
		}
		line_width {
			return WebGLParameterValue{ kind: .number, number: context.line_width_ }
		}
		scissor_box {
			return WebGLParameterValue{ kind: .integers, integers: context.scissor_[..].map(i64(it)) }
		}
		viewport {
			return WebGLParameterValue{ kind: .integers, integers: context.viewport_[..].map(i64(it)) }
		}
		stencil_clear_value {
			return WebGLParameterValue{ kind: .integer, integer: context.clear_stencil_ }
		}
		pack_alignment {
			return WebGLParameterValue{ kind: .integer, integer: context.pack_alignment_ }
		}
		unpack_alignment {
			return WebGLParameterValue{ kind: .integer, integer: context.unpack_alignment_ }
		}
		compressed_texture_formats {
			return WebGLParameterValue{ kind: .integers, integers: context.enabled_compressed_texture_formats_.map(i64(it)) }
		}
		unpack_flip_y_webgl {
			return WebGLParameterValue{ kind: .boolean, boolean: context.unpack_flip_y_ }
		}
		unpack_premultiply_alpha_webgl {
			return WebGLParameterValue{ kind: .boolean, boolean: context.unpack_premultiply_alpha_ }
		}
		unpack_colorspace_conversion_webgl {
			return WebGLParameterValue{ kind: .integer, integer: context.unpack_colorspace_conversion_ }
		}
		unmasked_vendor_webgl, unmasked_renderer_webgl {
			if !context.extension_enabled('WEBGL_debug_renderer_info') {
				context.set_error(invalid_enum)
				return WebGLParameterValue{}
			}
			return WebGLParameterValue{
				kind: .string_
				text: if pname == unmasked_vendor_webgl {
					context.native.vendor()
				} else {
					context.native.renderer()
				}
			}
		}
		else {}
	}
	if context.version == .webgl2 {
		match pname {
			texture_binding_3d, texture_binding_2d_array {
				target := if pname == texture_binding_3d { texture_3d } else { texture_2d_array }
				handle := context.bound_textures[target] or { return WebGLParameterValue{} }
				return WebGLParameterValue{ kind: .object, object: handle }
			}
			pack_row_length, pack_skip_rows, pack_skip_pixels, unpack_row_length, unpack_skip_rows, unpack_skip_pixels, unpack_skip_images, unpack_image_height {
				return context.generic_parameters_[pname] or { integer_parameter(0) }
			}
			copy_read_buffer, copy_write_buffer, pixel_pack_buffer_binding, pixel_unpack_buffer_binding, uniform_buffer_binding, transform_feedback_buffer_binding {
				target := match pname {
					copy_read_buffer { copy_read_buffer }
					copy_write_buffer { copy_write_buffer }
					pixel_pack_buffer_binding { pixel_pack_buffer }
					pixel_unpack_buffer_binding { pixel_unpack_buffer }
					uniform_buffer_binding { uniform_buffer }
					else { transform_feedback_buffer }
				}
				handle := context.bound_buffers[target] or { return WebGLParameterValue{} }
				return WebGLParameterValue{ kind: .object, object: handle }
			}
			transform_feedback_binding {
				feedback := context.current_transform_feedback or { return WebGLParameterValue{} }
				return WebGLParameterValue{ kind: .object, object: feedback.object.handle_ }
			}
			transform_feedback_active {
				feedback := context.current_transform_feedback or { return WebGLParameterValue{ kind: .boolean } }
				return WebGLParameterValue{ kind: .boolean, boolean: feedback.active_ }
			}
			transform_feedback_paused {
				feedback := context.current_transform_feedback or { return WebGLParameterValue{ kind: .boolean } }
				return WebGLParameterValue{ kind: .boolean, boolean: feedback.paused_ }
			}
			rasterizer_discard {
				return WebGLParameterValue{ kind: .boolean, boolean: context.is_enabled(pname) }
			}
			sampler_binding {
				unit := GLuint(context.active_texture_ - texture0)
				handle := context.bound_samplers[unit] or { return WebGLParameterValue{} }
				return WebGLParameterValue{ kind: .object, object: handle }
			}
			vertex_array_binding {
				array := context.current_vertex_array or { return WebGLParameterValue{} }
				return WebGLParameterValue{ kind: .object, object: array.object.handle_ }
			}
			else {}
		}
	}
	if pname == fragment_shader_derivative_hint
		&& (context.version == .webgl2 || context.extension_enabled('OES_standard_derivatives')) {
		return context.generic_parameters_[pname] or { integer_parameter(dont_care) }
	}
	if value := context.generic_parameters_[pname] {
		return value
	}
	context.set_error(invalid_enum)
	return WebGLParameterValue{}
}

pub fn (mut context WebGLRenderingContext) get_renderbuffer_parameter(_ GLenum, pname GLenum) WebGLParameterValue {
	buffer := context.renderbuffers[context.bound_renderbuffer] or {
		context.set_error(invalid_operation)
		return WebGLParameterValue{}
	}
	value := match pname {
		0x8d42 { i64(buffer.width_) }
		0x8d43 { i64(buffer.height_) }
		else { i64(buffer.internal_format_) }
	}
	return WebGLParameterValue{ kind: .integer, integer: value }
}

pub fn (mut context WebGLRenderingContext) get_tex_parameter(target GLenum, pname GLenum) WebGLParameterValue {
	handle := context.bound_textures[target] or {
		context.set_error(invalid_operation)
		return WebGLParameterValue{}
	}
	texture := context.textures[handle] or { return WebGLParameterValue{} }
	if value := texture.parameters_i_[pname] {
		return WebGLParameterValue{ kind: .integer, integer: value }
	}
	if value := texture.parameters_f_[pname] {
		return WebGLParameterValue{ kind: .number, number: value }
	}
	return WebGLParameterValue{}
}

pub fn (context &WebGLRenderingContext) get_uniform(_ &WebGLProgram, location ?&WebGLUniformLocation) WebGLParameterValue {
	value := location or { return WebGLParameterValue{} }
	values := context.uniform_values_[value.handle_] or { return WebGLParameterValue{} }
	return WebGLParameterValue{ kind: .numbers, numbers: values.map(f64(it)) }
}

pub fn (context &WebGLRenderingContext) get_active_attrib(_ &WebGLProgram, index GLuint) ?WebGLActiveInfo {
	return WebGLActiveInfo.create('attribute_${index}', GLenum(0x1406), 1)
}

pub fn (context &WebGLRenderingContext) get_active_uniform(_ &WebGLProgram, index GLuint) ?WebGLActiveInfo {
	return WebGLActiveInfo.create('uniform_${index}', GLenum(0x1406), 1)
}

pub fn (context &WebGLRenderingContext) get_attrib_location(_ &WebGLProgram, name string) int {
	return if name == '' || name.starts_with('gl_') { -1 } else { int(name.hash() & 0x7fff) }
}

pub fn (mut context WebGLRenderingContext) get_vertex_attrib(index GLuint, pname GLenum) WebGLParameterValue {
	state := context.vertex_attrib_states_[index] or { VertexAttribState{} }
	return match pname {
		current_vertex_attrib {
			values := context.vertex_attrib_values_[index] or { [f32(0), 0, 0, 1] }
			WebGLParameterValue{ kind: .numbers, numbers: values.map(f64(it)) }
		}
		vertex_attrib_array_buffer_binding {
			if state.buffer_handle == 0 {
				WebGLParameterValue{}
			} else {
				WebGLParameterValue{ kind: .object, object: state.buffer_handle }
			}
		}
		vertex_attrib_array_divisor {
			if context.version == .webgl2 || context.extension_enabled('ANGLE_instanced_arrays') {
				WebGLParameterValue{ kind: .integer, integer: state.divisor }
			} else {
				context.set_error(invalid_enum)
				WebGLParameterValue{}
			}
		}
		vertex_attrib_array_enabled {
			WebGLParameterValue{
				kind: .boolean
				boolean: index in context.enabled_vertex_attributes
			}
		}
		vertex_attrib_array_integer {
			if context.version == .webgl2 {
				WebGLParameterValue{ kind: .boolean, boolean: state.integer }
			} else {
				context.set_error(invalid_enum)
				WebGLParameterValue{}
			}
		}
		vertex_attrib_array_normalized {
			WebGLParameterValue{ kind: .boolean, boolean: state.normalized }
		}
		vertex_attrib_array_size { WebGLParameterValue{ kind: .integer, integer: state.size } }
		vertex_attrib_array_stride { WebGLParameterValue{ kind: .integer, integer: state.stride } }
		vertex_attrib_array_type { WebGLParameterValue{ kind: .integer, integer: state.type_ } }
		else {
			context.set_error(invalid_enum)
			WebGLParameterValue{}
		}
	}
}

pub fn (mut context WebGLRenderingContext) get_vertex_attrib_offset(index GLuint, pname GLenum) i64 {
	if pname != vertex_attrib_array_pointer {
		context.set_error(invalid_enum)
		return 0
	}
	return (context.vertex_attrib_states_[index] or { VertexAttribState{} }).offset
}

pub fn (mut context WebGLRenderingContext) is_framebuffer(value ?&WebGLFramebuffer) bool {
	object := value or { return false }
	handle := context.object_handle_for_query(&object.object) or { return false }
	return handle in context.framebuffers
}

pub fn (mut context WebGLRenderingContext) is_renderbuffer(value ?&WebGLRenderbuffer) bool {
	object := value or { return false }
	handle := context.object_handle_for_query(&object.object) or { return false }
	return handle in context.renderbuffers
}

pub fn (mut context WebGLRenderingContext) is_texture(value ?&WebGLTexture) bool {
	object := value or { return false }
	handle := context.object_handle_for_query(&object.object) or { return false }
	return handle in context.textures
}

pub fn (mut context WebGLRenderingContext) is_shader(value ?&WebGLShader) bool {
	object := value or { return false }
	handle := context.object_handle_for_query(&object.object) or { return false }
	return handle in context.shaders
}

pub fn (mut context WebGLRenderingContext) is_program(value ?&WebGLProgram) bool {
	object := value or { return false }
	handle := context.object_handle_for_query(&object.object) or { return false }
	return handle in context.programs
}

pub fn (mut context WebGLRenderingContext) line_width(width f32) {
	if width <= 0 {
		context.set_error(invalid_value)
		return
	}
	context.line_width_ = width
	context.command('line_width', i64(width))
}

pub fn (mut context WebGLRenderingContext) polygon_offset(factor f32, units f32) {
	context.generic_parameters_[polygon_offset_factor] = number_parameter(factor)
	context.generic_parameters_[polygon_offset_units] = number_parameter(units)
	context.command('polygon_offset', i64(factor), i64(units))
}

pub fn (mut context WebGLRenderingContext) renderbuffer_storage(target GLenum, internal_format GLenum, width int, height int) {
	if width < 0 || height < 0 {
		context.set_error(invalid_value)
		return
	}
	mut buffer := context.renderbuffers[context.bound_renderbuffer] or {
		context.set_error(invalid_operation)
		return
	}
	buffer.internal_format_ = internal_format
	buffer.width_ = width
	buffer.height_ = height
	context.command('renderbuffer_storage', target, internal_format, width, height)
}

pub fn (mut context WebGLRenderingContext) sample_coverage(value f32, invert bool) {
	context.generic_parameters_[sample_coverage_value] = number_parameter(clamp_unit(value))
	context.generic_parameters_[sample_coverage_invert] = boolean_parameter(invert)
	context.command('sample_coverage', i64(value), i64(invert))
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
	handle := context.bound_textures[target] or {
		context.set_error(invalid_operation)
		return
	}
	mut texture := context.textures[handle] or { return }
	texture.parameters_i_[pname] = parameter
	context.command('tex_parameteri', target, pname, parameter)
}

pub fn (mut context WebGLRenderingContext) tex_parameterf(target GLenum, pname GLenum, parameter f32) {
	handle := context.bound_textures[target] or {
		context.set_error(invalid_operation)
		return
	}
	mut texture := context.textures[handle] or { return }
	texture.parameters_f_[pname] = parameter
	context.command('tex_parameterf', target, pname, i64(parameter))
}

fn (mut context WebGLRenderingContext) uniform_floats(location ?&WebGLUniformLocation, values []f32) {
	value := location or { return }
	value.handle(context.current_program) or {
		context.set_error(invalid_operation)
		return
	}
	context.uniform_values_[value.handle_] = values.clone()
	context.set_uniform(location, values)
}

pub fn (mut context WebGLRenderingContext) uniform1f(location ?&WebGLUniformLocation, x f32) {
	context.uniform_floats(location, [x])
}

pub fn (mut context WebGLRenderingContext) uniform2f(location ?&WebGLUniformLocation, x f32, y f32) {
	context.uniform_floats(location, [x, y])
}

pub fn (mut context WebGLRenderingContext) uniform3f(location ?&WebGLUniformLocation, x f32, y f32, z f32) {
	context.uniform_floats(location, [x, y, z])
}

pub fn (mut context WebGLRenderingContext) uniform4f(location ?&WebGLUniformLocation, x f32, y f32, z f32, w f32) {
	context.uniform_floats(location, [x, y, z, w])
}

pub fn (mut context WebGLRenderingContext) uniform1i(location ?&WebGLUniformLocation, x int) {
	context.uniform_floats(location, [f32(x)])
}

pub fn (mut context WebGLRenderingContext) uniform2i(location ?&WebGLUniformLocation, x int, y int) {
	context.uniform_floats(location, [f32(x), f32(y)])
}

pub fn (mut context WebGLRenderingContext) uniform3i(location ?&WebGLUniformLocation, x int, y int, z int) {
	context.uniform_floats(location, [f32(x), f32(y), f32(z)])
}

pub fn (mut context WebGLRenderingContext) uniform4i(location ?&WebGLUniformLocation, x int, y int, z int, w int) {
	context.uniform_floats(location, [f32(x), f32(y), f32(z), f32(w)])
}

pub fn (mut context WebGLRenderingContext) vertex_attrib1f(index GLuint, x f32) {
	context.vertex_attrib_values_[index] = [x, f32(0), 0, 1]
}

pub fn (mut context WebGLRenderingContext) vertex_attrib2f(index GLuint, x f32, y f32) {
	context.vertex_attrib_values_[index] = [x, y, f32(0), 1]
}

pub fn (mut context WebGLRenderingContext) vertex_attrib3f(index GLuint, x f32, y f32, z f32) {
	context.vertex_attrib_values_[index] = [x, y, z, f32(1)]
}

pub fn (mut context WebGLRenderingContext) vertex_attrib4f(index GLuint, x f32, y f32, z f32, w f32) {
	context.vertex_attrib_values_[index] = [x, y, z, w]
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
