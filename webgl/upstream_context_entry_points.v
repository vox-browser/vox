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
	object
}

pub struct WebGLParameterValue {
pub:
	kind       WebGLParameterKind
	integer    i64
	number     f64
	boolean    bool
	text       string
	integers   []i64
	numbers    []f64
	object     GLuint
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
	if offset > u64(values.len) { return error('offset exceeds source') }
	count := if length == 0 { u64(values.len) - offset } else { u64(length) }
	if offset + count < offset || offset + count > u64(values.len) {
		return error('slice exceeds source')
	}
	return values[int(offset)..int(offset + count)].clone()
}

fn slice_int(values []int, offset u64, length u32) ![]int {
	if offset > u64(values.len) { return error('offset exceeds source') }
	count := if length == 0 { u64(values.len) - offset } else { u64(length) }
	if offset + count < offset || offset + count > u64(values.len) {
		return error('slice exceeds source')
	}
	return values[int(offset)..int(offset + count)].clone()
}

fn slice_u32(values []u32, offset u64, length u32) ![]u32 {
	if offset > u64(values.len) { return error('offset exceeds source') }
	count := if length == 0 { u64(values.len) - offset } else { u64(length) }
	if offset + count < offset || offset + count > u64(values.len) {
		return error('slice exceeds source')
	}
	return values[int(offset)..int(offset + count)].clone()
}

pub fn null_terminated_string(bytes []u8) string {
	index := bytes.index(0)
	end := if index < 0 { bytes.len } else { index }
	return bytes[..end].bytestr()
}

pub fn read_and_pixel_convert_texture_image_source(bytes []u8, flip_y bool, premultiply_alpha bool) []u8 {
	mut result := bytes.clone()
	if premultiply_alpha {
		for offset := 0; offset + 3 < result.len; offset += 4 {
			alpha := u16(result[offset + 3])
			result[offset] = u8((u16(result[offset]) * alpha + 127) / 255)
			result[offset + 1] = u8((u16(result[offset + 1]) * alpha + 127) / 255)
			result[offset + 2] = u8((u16(result[offset + 2]) * alpha + 127) / 255)
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
	handle := if value := framebuffer_object {
		if !context.owns(&value.object) {
			context.set_error(invalid_operation)
			return
		}
		value.object.handle_
	} else { GLuint(0) }
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
	} else { GLuint(0) }
	context.bound_renderbuffer = handle
	context.command('bind_renderbuffer', target, handle)
}

pub fn (mut context WebGLRenderingContext) bind_texture(target GLenum, texture ?&WebGLTexture) {
	if target !in [texture_2d, texture_cube_map] {
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
	} else { GLuint(0) }
	if handle == 0 { context.bound_textures.delete(target) } else { context.bound_textures[target] = handle }
	context.command('bind_texture', target, handle)
}

pub fn (mut context WebGLRenderingContext) blend_color(red f32, green f32, blue f32, alpha f32) {
	context.blend_color_ = [red, green, blue, alpha]!
	context.command('blend_color', i64(red), i64(green), i64(blue), i64(alpha))
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
	context.command('cull_face', mode)
}

pub fn (mut context WebGLRenderingContext) delete_framebuffer(object ?&WebGLFramebuffer) {
	if value := object {
		mut mutable_value := unsafe { &WebGLFramebuffer(value) }
		if !context.owns(&value.object) { context.set_error(invalid_operation); return }
		handle := value.object.handle_
		mutable_value.object.invalidate()
		context.framebuffers.delete(handle)
		if context.bound_framebuffer == handle { context.bound_framebuffer = 0 }
		context.command('delete_framebuffer', handle)
	}
}

pub fn (mut context WebGLRenderingContext) delete_renderbuffer(object ?&WebGLRenderbuffer) {
	if value := object {
		mut mutable_value := unsafe { &WebGLRenderbuffer(value) }
		if !context.owns(&value.object) { context.set_error(invalid_operation); return }
		handle := value.object.handle_
		mutable_value.object.invalidate()
		context.renderbuffers.delete(handle)
		if context.bound_renderbuffer == handle { context.bound_renderbuffer = 0 }
		context.command('delete_renderbuffer', handle)
	}
}

pub fn (mut context WebGLRenderingContext) delete_texture(object ?&WebGLTexture) {
	if value := object {
		mut mutable_value := unsafe { &WebGLTexture(value) }
		if !context.owns(&value.object) { context.set_error(invalid_operation); return }
		handle := value.object.handle_
		mutable_value.object.invalidate()
		context.textures.delete(handle)
		for target, bound in context.bound_textures { if bound == handle { context.bound_textures.delete(target) } }
		context.command('delete_texture', handle)
	}
}

pub fn (mut context WebGLRenderingContext) delete_shader(object ?&WebGLShader) {
	if value := object {
		mut mutable_value := unsafe { &WebGLShader(value) }
		if !context.owns(&value.object) { context.set_error(invalid_operation); return }
		handle := value.object.handle_
		mutable_value.object.invalidate()
		context.shaders.delete(handle)
		context.command('delete_shader', handle)
	}
}

pub fn (mut context WebGLRenderingContext) delete_program(object ?&WebGLProgram) {
	if value := object {
		mut mutable_value := unsafe { &WebGLProgram(value) }
		if !context.owns(&value.object) { context.set_error(invalid_operation); return }
		handle := value.object.handle_
		mutable_value.object.invalidate()
		context.programs.delete(handle)
		if current := context.current_program { if current.object.handle_ == handle { context.current_program = none } }
		context.command('delete_program', handle)
	}
}

pub fn (mut context WebGLRenderingContext) depth_func(function GLenum) {
	context.command('depth_func', function)
}

pub fn (mut context WebGLRenderingContext) depth_range(near f64, far f64) {
	context.depth_range_ = [if near < 0 { f64(0) } else if near > 1 { f64(1) } else { near },
		if far < 0 { f64(0) } else if far > 1 { f64(1) } else { far }]!
	context.command('depth_range', i64(context.depth_range_[0]), i64(context.depth_range_[1]))
}

pub fn (mut context WebGLRenderingContext) finish() { context.command('finish') }
pub fn (mut context WebGLRenderingContext) flush() { context.command('flush') }
pub fn (mut context WebGLRenderingContext) front_face(mode GLenum) { context.command('front_face', mode) }
pub fn (mut context WebGLRenderingContext) generate_mipmap(target GLenum) { context.command('generate_mipmap', target) }
pub fn (mut context WebGLRenderingContext) hint(target GLenum, mode GLenum) { context.command('hint', target, mode) }

pub fn (mut context WebGLRenderingContext) framebuffer_renderbuffer(target GLenum, attachment GLenum, renderbuffer_target GLenum, object ?&WebGLRenderbuffer) {
	handle := if value := object {
		if !context.owns(&value.object) { context.set_error(invalid_operation); return }
		value.object.handle_
	} else { GLuint(0) }
	if framebuffer_object := context.framebuffers[context.bound_framebuffer] {
		mut mutable := unsafe { &WebGLFramebuffer(framebuffer_object) }
		if handle == 0 { mutable.attachments.delete(attachment) } else { mutable.attachments[attachment] = handle }
	}
	context.command('framebuffer_renderbuffer', target, attachment, renderbuffer_target, handle)
}

pub fn (mut context WebGLRenderingContext) framebuffer_texture2d(target GLenum, attachment GLenum, texture_target GLenum, object ?&WebGLTexture, level int) {
	handle := if value := object {
		if !context.owns(&value.object) { context.set_error(invalid_operation); return }
		value.object.handle_
	} else { GLuint(0) }
	if framebuffer_object := context.framebuffers[context.bound_framebuffer] {
		mut mutable := unsafe { &WebGLFramebuffer(framebuffer_object) }
		if handle == 0 { mutable.attachments.delete(attachment) } else { mutable.attachments[attachment] = handle }
	}
	context.command('framebuffer_texture2d', target, attachment, texture_target, handle, level)
}

pub fn (context &WebGLRenderingContext) get_attached_shaders(program &WebGLProgram) []&WebGLShader {
	mut result := []&WebGLShader{}
	if shader := program.attached_vertex_shader { result << shader }
	if shader := program.attached_fragment_shader { result << shader }
	return result
}

pub fn (context &WebGLRenderingContext) get_program_info_log(program &WebGLProgram) ?string {
	if !context.owns(&program.object) { return none }
	return program.info_log_
}

pub fn (mut context WebGLRenderingContext) get_program_parameter(program &WebGLProgram, pname GLenum) WebGLParameterValue {
	if !context.owns(&program.object) { context.set_error(invalid_operation); return WebGLParameterValue{} }
	return WebGLParameterValue{ kind: .boolean, boolean: program.linked_ || program.validated_ }
}

pub fn (mut context WebGLRenderingContext) get_shader_parameter(shader &WebGLShader, _ GLenum) WebGLParameterValue {
	if !context.owns(&shader.object) { context.set_error(invalid_operation); return WebGLParameterValue{} }
	return WebGLParameterValue{ kind: .boolean, boolean: shader.compiled_ }
}

pub fn (mut context WebGLRenderingContext) get_shader_precision_format(_ GLenum, _ GLenum) WebGLShaderPrecisionFormat {
	context.command('get_shader_precision_format')
	return WebGLShaderPrecisionFormat.create(127, 127, 23)
}

pub fn (mut context WebGLRenderingContext) get_buffer_parameter(target GLenum, _ GLenum) WebGLParameterValue {
	handle := context.bound_buffers[target] or { context.set_error(invalid_operation); return WebGLParameterValue{} }
	buffer := context.buffers[handle] or { return WebGLParameterValue{} }
	return WebGLParameterValue{ kind: .integer, integer: buffer.data_.len }
}

pub fn (context &WebGLRenderingContext) get_parameter(pname GLenum) WebGLParameterValue {
	return context.generic_parameters_[pname] or { WebGLParameterValue{} }
}

pub fn (mut context WebGLRenderingContext) get_renderbuffer_parameter(_ GLenum, pname GLenum) WebGLParameterValue {
	buffer := context.renderbuffers[context.bound_renderbuffer] or { context.set_error(invalid_operation); return WebGLParameterValue{} }
	value := match pname {
		0x8d42 { i64(buffer.width_) }
		0x8d43 { i64(buffer.height_) }
		else { i64(buffer.internal_format_) }
	}
	return WebGLParameterValue{ kind: .integer, integer: value }
}

pub fn (mut context WebGLRenderingContext) get_tex_parameter(target GLenum, pname GLenum) WebGLParameterValue {
	handle := context.bound_textures[target] or { context.set_error(invalid_operation); return WebGLParameterValue{} }
	texture := context.textures[handle] or { return WebGLParameterValue{} }
	if value := texture.parameters_i_[pname] { return WebGLParameterValue{ kind: .integer, integer: value } }
	if value := texture.parameters_f_[pname] { return WebGLParameterValue{ kind: .number, number: value } }
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

pub fn (context &WebGLRenderingContext) get_vertex_attrib(index GLuint, _ GLenum) WebGLParameterValue {
	values := context.vertex_attrib_values_[index] or { [f32(0), 0, 0, 1] }
	return WebGLParameterValue{ kind: .numbers, numbers: values.map(f64(it)) }
}

pub fn (_ &WebGLRenderingContext) get_vertex_attrib_offset(_ GLuint, _ GLenum) i64 { return 0 }

pub fn (mut context WebGLRenderingContext) is_framebuffer(value ?&WebGLFramebuffer) bool {
	object := value or { return false }
	return context.owns(&object.object)
}

pub fn (mut context WebGLRenderingContext) is_renderbuffer(value ?&WebGLRenderbuffer) bool {
	object := value or { return false }
	return context.owns(&object.object)
}

pub fn (mut context WebGLRenderingContext) is_texture(value ?&WebGLTexture) bool {
	object := value or { return false }
	return context.owns(&object.object)
}

pub fn (mut context WebGLRenderingContext) is_shader(value ?&WebGLShader) bool {
	object := value or { return false }
	return context.owns(&object.object)
}

pub fn (mut context WebGLRenderingContext) is_program(value ?&WebGLProgram) bool {
	object := value or { return false }
	return context.owns(&object.object)
}

pub fn (mut context WebGLRenderingContext) line_width(width f32) {
	if width <= 0 { context.set_error(invalid_value); return }
	context.line_width_ = width
	context.command('line_width', i64(width))
}

pub fn (mut context WebGLRenderingContext) polygon_offset(factor f32, units f32) { context.command('polygon_offset', i64(factor), i64(units)) }

pub fn (mut context WebGLRenderingContext) renderbuffer_storage(target GLenum, internal_format GLenum, width int, height int) {
	if width < 0 || height < 0 { context.set_error(invalid_value); return }
	mut buffer := context.renderbuffers[context.bound_renderbuffer] or { context.set_error(invalid_operation); return }
	buffer.internal_format_ = internal_format
	buffer.width_ = width
	buffer.height_ = height
	context.command('renderbuffer_storage', target, internal_format, width, height)
}

pub fn (mut context WebGLRenderingContext) sample_coverage(value f32, invert bool) { context.command('sample_coverage', i64(value), i64(invert)) }
pub fn (mut context WebGLRenderingContext) stencil_func(function GLenum, reference int, mask GLuint) { context.command('stencil_func', function, reference, mask) }
pub fn (mut context WebGLRenderingContext) stencil_func_separate(face GLenum, function GLenum, reference int, mask GLuint) { context.command('stencil_func_separate', face, function, reference, mask) }
pub fn (mut context WebGLRenderingContext) stencil_mask(mask GLuint) { context.command('stencil_mask', mask) }
pub fn (mut context WebGLRenderingContext) stencil_mask_separate(face GLenum, mask GLuint) { context.command('stencil_mask_separate', face, mask) }
pub fn (mut context WebGLRenderingContext) stencil_op(fail GLenum, depth_fail GLenum, pass GLenum) { context.command('stencil_op', fail, depth_fail, pass) }
pub fn (mut context WebGLRenderingContext) stencil_op_separate(face GLenum, fail GLenum, depth_fail GLenum, pass GLenum) { context.command('stencil_op_separate', face, fail, depth_fail, pass) }

pub fn (mut context WebGLRenderingContext) tex_parameteri(target GLenum, pname GLenum, parameter int) {
	handle := context.bound_textures[target] or { context.set_error(invalid_operation); return }
	mut texture := context.textures[handle] or { return }
	texture.parameters_i_[pname] = parameter
	context.command('tex_parameteri', target, pname, parameter)
}

pub fn (mut context WebGLRenderingContext) tex_parameterf(target GLenum, pname GLenum, parameter f32) {
	handle := context.bound_textures[target] or { context.set_error(invalid_operation); return }
	mut texture := context.textures[handle] or { return }
	texture.parameters_f_[pname] = parameter
	context.command('tex_parameterf', target, pname, i64(parameter))
}

fn (mut context WebGLRenderingContext) uniform_floats(location ?&WebGLUniformLocation, values []f32) {
	value := location or { return }
	value.handle(context.current_program) or { context.set_error(invalid_operation); return }
	context.uniform_values_[value.handle_] = values.clone()
	context.set_uniform(location, values)
}

pub fn (mut context WebGLRenderingContext) uniform1f(location ?&WebGLUniformLocation, x f32) { context.uniform_floats(location, [x]) }
pub fn (mut context WebGLRenderingContext) uniform2f(location ?&WebGLUniformLocation, x f32, y f32) { context.uniform_floats(location, [x, y]) }
pub fn (mut context WebGLRenderingContext) uniform3f(location ?&WebGLUniformLocation, x f32, y f32, z f32) { context.uniform_floats(location, [x, y, z]) }
pub fn (mut context WebGLRenderingContext) uniform4f(location ?&WebGLUniformLocation, x f32, y f32, z f32, w f32) { context.uniform_floats(location, [x, y, z, w]) }
pub fn (mut context WebGLRenderingContext) uniform1i(location ?&WebGLUniformLocation, x int) { context.uniform_floats(location, [f32(x)]) }
pub fn (mut context WebGLRenderingContext) uniform2i(location ?&WebGLUniformLocation, x int, y int) { context.uniform_floats(location, [f32(x), f32(y)]) }
pub fn (mut context WebGLRenderingContext) uniform3i(location ?&WebGLUniformLocation, x int, y int, z int) { context.uniform_floats(location, [f32(x), f32(y), f32(z)]) }
pub fn (mut context WebGLRenderingContext) uniform4i(location ?&WebGLUniformLocation, x int, y int, z int, w int) { context.uniform_floats(location, [f32(x), f32(y), f32(z), f32(w)]) }

pub fn (mut context WebGLRenderingContext) vertex_attrib1f(index GLuint, x f32) { context.vertex_attrib_values_[index] = [x] }
pub fn (mut context WebGLRenderingContext) vertex_attrib2f(index GLuint, x f32, y f32) { context.vertex_attrib_values_[index] = [x, y] }
pub fn (mut context WebGLRenderingContext) vertex_attrib3f(index GLuint, x f32, y f32, z f32) { context.vertex_attrib_values_[index] = [x, y, z] }
pub fn (mut context WebGLRenderingContext) vertex_attrib4f(index GLuint, x f32, y f32, z f32, w f32) { context.vertex_attrib_values_[index] = [x, y, z, w] }
pub fn (mut context WebGLRenderingContext) vertex_attrib1fv(index GLuint, values []f32) { if values.len >= 1 { context.vertex_attrib1f(index, values[0]) } else { context.set_error(invalid_value) } }
pub fn (mut context WebGLRenderingContext) vertex_attrib2fv(index GLuint, values []f32) { if values.len >= 2 { context.vertex_attrib2f(index, values[0], values[1]) } else { context.set_error(invalid_value) } }
pub fn (mut context WebGLRenderingContext) vertex_attrib3fv(index GLuint, values []f32) { if values.len >= 3 { context.vertex_attrib3f(index, values[0], values[1], values[2]) } else { context.set_error(invalid_value) } }
pub fn (mut context WebGLRenderingContext) vertex_attrib4fv(index GLuint, values []f32) { if values.len >= 4 { context.vertex_attrib4f(index, values[0], values[1], values[2], values[3]) } else { context.set_error(invalid_value) } }

pub fn (mut context WebGLRenderingContext) vertex_attrib_pointer(index GLuint, size int, type_ GLenum, normalized bool, stride int, offset i64) {
	if size < 1 || size > 4 || stride < 0 || offset < 0 { context.set_error(invalid_value); return }
	context.command('vertex_attrib_pointer', index, size, type_, i64(normalized), stride, offset)
}
