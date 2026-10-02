// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Typed-array overloads and WebGL2 implementation operations.
module webgl

pub fn (_ &WebGLRenderingContext) get_offset_span(bytes []u8, offset u64, length u32) ![]u8 {
	return offset_span(bytes, offset, length)
}

pub fn (_ &WebGLRenderingContext) span_from_float32_list(values []f32, offset u64, length u32) ![]f32 {
	return slice_f32(values, offset, length)
}

pub fn (_ &WebGLRenderingContext) span_from_int32_list(values []int, offset u64, length u32) ![]int {
	return slice_int(values, offset, length)
}

pub fn (_ &WebGLRenderingContext) span_from_uint32_list(values []u32, offset u64, length u32) ![]u32 {
	return slice_u32(values, offset, length)
}

pub fn (_ &WebGLRenderingContext) null_terminated_string(bytes []u8) string {
	index := bytes.index(0)
	end := if index < 0 { bytes.len } else { index }
	return bytes[..end].bytestr()
}

pub fn (_ &WebGLRenderingContext) read_and_pixel_convert_texture_image_source(bytes []u8, flip_y bool, premultiply_alpha bool) []u8 {
	return read_and_pixel_convert_texture_image_source(bytes, flip_y, premultiply_alpha)
}

pub fn (context &WebGLRenderingContext) texture_data_for_2d_upload(bytes []u8, width GLsizei, height GLsizei, format GLenum, type_ GLenum) ![]u8 {
	if !is_valid_2d_pixel_unpack_state(width, context.unpack_state_) {
		return error('invalid 2D pixel unpack state')
	}
	required_size := required_2d_texture_data_size(width, height, format, type_, context.unpack_state_) or {
		return bytes
	}
	if required_size <= u64(bytes.len) {
		return bytes[..int(required_size)]
	}
	return bytes
}

pub fn (mut context WebGLRenderingContext) compressed_tex_image2d(target GLenum, level int, internal_format GLenum, width int, height int, border int, data []u8) {
	if internal_format !in context.enabled_compressed_texture_formats_ {
		context.set_error(invalid_enum)
		return
	}
	if width < 0 || height < 0 || border != 0 {
		context.set_error(invalid_value)
		return
	}
	context.command('compressed_tex_image2d', target, level, internal_format, width, height, border, data.len)
}

pub fn (mut context WebGLRenderingContext) compressed_tex_sub_image2d(target GLenum, level int, x_offset int, y_offset int, width int, height int, format GLenum, data []u8) {
	if format !in context.enabled_compressed_texture_formats_ {
		context.set_error(invalid_enum)
		return
	}
	if width < 0 || height < 0 {
		context.set_error(invalid_value)
		return
	}
	context.command('compressed_tex_sub_image2d', target, level, x_offset, y_offset, width, height, format, data.len)
}

pub fn (mut context WebGLRenderingContext) tex_image2d(target GLenum, level int, internal_format GLenum, width int, height int, border int, format GLenum, type_ GLenum, pixels []u8) {
	if width < 0 || height < 0 || border != 0 {
		context.set_error(invalid_value)
		return
	}
	texture_data := context.texture_data_for_2d_upload(pixels, width, height, format, type_) or {
		context.set_error(invalid_operation)
		return
	}
	if handle := context.bound_textures[target] {
		mut texture := context.textures[handle] or { return }
		texture.width_ = width
		texture.height_ = height
		texture.depth_ = 1
		texture.internal_format_ = internal_format
	}
	context.command('tex_image2d', target, level, internal_format, width, height, border, format, type_, texture_data.len)
	C.vox_gl_tex_image2d(target, level, internal_format, width, height, border, format, type_, texture_data.len, texture_data.data)
	context.native.collect_native_error()
}

pub fn (mut context WebGLRenderingContext) tex_sub_image2d(target GLenum, level int, x_offset int, y_offset int, width int, height int, format GLenum, type_ GLenum, pixels []u8) {
	if width < 0 || height < 0 {
		context.set_error(invalid_value)
		return
	}
	if target !in context.bound_textures {
		context.set_error(invalid_operation)
		return
	}
	texture_data := context.texture_data_for_2d_upload(pixels, width, height, format, type_) or {
		context.set_error(invalid_operation)
		return
	}
	context.command('tex_sub_image2d', target, level, x_offset, y_offset, width, height, format, type_, texture_data.len)
	C.vox_gl_tex_sub_image2d(target, level, x_offset, y_offset, width, height, format, type_, texture_data.len, texture_data.data)
	context.native.collect_native_error()
}

pub fn (mut context WebGLRenderingContext) read_pixels(x int, y int, width int, height int, format GLenum, type_ GLenum) []u8 {
	if width < 0 || height < 0 {
		context.set_error(invalid_value)
		return []u8{}
	}
	context.command('read_pixels', x, y, width, height, format, type_)
	capacity := required_2d_texture_data_size(width, height, format, type_, PixelUnpackState{alignment: u64(context.pack_alignment_)}) or {
 context.set_error(invalid_enum); return []u8{}
 }
 if capacity > u64(max_int) { context.set_error(out_of_memory); return []u8{} }
 mut data := []u8{len: int(capacity)}
 written := C.vox_gl_read_pixels(x, y, width, height, format, type_, data.len, data.data)
 context.native.collect_native_error()
 if written <= 0 { return []u8{} }
 return data[..written].clone()
}

fn ints_to_floats(values []int) []f32 {
	return values.map(f32(it))
}

pub fn (mut context WebGLRenderingContext) uniform1fv(location ?&WebGLUniformLocation, values []f32) {
 context.uniform_floats(location, values, 1)
}

pub fn (mut context WebGLRenderingContext) uniform2fv(location ?&WebGLUniformLocation, values []f32) {
 context.uniform_floats(location, values, 2)
}

pub fn (mut context WebGLRenderingContext) uniform3fv(location ?&WebGLUniformLocation, values []f32) {
 context.uniform_floats(location, values, 3)
}

pub fn (mut context WebGLRenderingContext) uniform4fv(location ?&WebGLUniformLocation, values []f32) {
 context.uniform_floats(location, values, 4)
}

pub fn (mut context WebGLRenderingContext) uniform1iv(location ?&WebGLUniformLocation, values []int) {
 context.uniform_ints(location, values, 1)
}

pub fn (mut context WebGLRenderingContext) uniform2iv(location ?&WebGLUniformLocation, values []int) {
 context.uniform_ints(location, values, 2)
}

pub fn (mut context WebGLRenderingContext) uniform3iv(location ?&WebGLUniformLocation, values []int) {
 context.uniform_ints(location, values, 3)
}

pub fn (mut context WebGLRenderingContext) uniform4iv(location ?&WebGLUniformLocation, values []int) {
 context.uniform_ints(location, values, 4)
}

fn (mut context WebGLRenderingContext) uniform_matrix(location ?&WebGLUniformLocation, transpose bool, values []f32, columns int, rows int) {
 value := location or { return }
 value.handle(context.current_program) or { context.set_error(invalid_operation); return }
 if transpose || values.len % (columns * rows) != 0 { context.set_error(invalid_value); return }
 if columns != rows && !context.require_webgl2() { return }
 context.native.make_current()
	C.vox_gl_uniform_matrix(int(value.handle_), columns, rows, values.len / (columns * rows), values.data)
	error_value := GLenum(C.vox_gl_get_error())
	if error_value != no_error { context.native.set_pending_local_error(error_value); return }
	context.uniform_values_[value.handle_] = values.clone()
}

pub fn (mut context WebGLRenderingContext) uniform_matrix2fv(location ?&WebGLUniformLocation, transpose bool, values []f32) {
	context.uniform_matrix(location, transpose, values, 2, 2)
}

pub fn (mut context WebGLRenderingContext) uniform_matrix3fv(location ?&WebGLUniformLocation, transpose bool, values []f32) {
	context.uniform_matrix(location, transpose, values, 3, 3)
}

pub fn (mut context WebGLRenderingContext) uniform_matrix4fv(location ?&WebGLUniformLocation, transpose bool, values []f32) {
	context.uniform_matrix(location, transpose, values, 4, 4)
}

pub fn (mut context WebGLRenderingContext) bind_buffer_base(target GLenum, index GLuint, buffer ?&WebGLBuffer) {
	if !context.require_webgl2() {
		return
	}
	handle := if value := buffer {
		if !context.owns(&value.object) {
			context.set_error(invalid_operation)
			return
		}
		value.object.handle_
	} else {
		GLuint(0)
	}
	context.command('bind_buffer_base', target, index, handle)
}

pub fn (mut context WebGLRenderingContext) bind_buffer_range(target GLenum, index GLuint, buffer ?&WebGLBuffer, offset i64, size i64) {
	if offset < 0 || size <= 0 {
		context.set_error(invalid_value)
		return
	}
	handle := if value := buffer {
		if !context.owns(&value.object) {
			context.set_error(invalid_operation)
			return
		}
		value.object.handle_
	} else {
		GLuint(0)
	}
	context.webgl2_command('bind_buffer_range', target, index, handle, offset, size)
}

pub fn (mut context WebGLRenderingContext) blit_framebuffer(source_x0 int, source_y0 int, source_x1 int, source_y1 int, destination_x0 int, destination_y0 int, destination_x1 int, destination_y1 int, mask GLenum, filter GLenum) {
	context.webgl2_command('blit_framebuffer', source_x0, source_y0, source_x1, source_y1, destination_x0, destination_y0, destination_x1, destination_y1, mask, filter)
}

pub fn (mut context WebGLRenderingContext) clear_bufferfv(buffer GLenum, draw_buffer int, values []f32) {
	context.webgl2_command('clear_bufferfv', buffer, draw_buffer, values.len)
}

pub fn (mut context WebGLRenderingContext) clear_bufferiv(buffer GLenum, draw_buffer int, values []int) {
	context.webgl2_command('clear_bufferiv', buffer, draw_buffer, values.len)
}

pub fn (mut context WebGLRenderingContext) clear_bufferuiv(buffer GLenum, draw_buffer int, values []u32) {
	context.webgl2_command('clear_bufferuiv', buffer, draw_buffer, values.len)
}

pub fn (mut context WebGLRenderingContext) clear_bufferfi(buffer GLenum, draw_buffer int, depth f32, stencil int) {
	context.webgl2_command('clear_bufferfi', buffer, draw_buffer, i64(depth), stencil)
}

pub fn (mut context WebGLRenderingContext) compressed_tex_sub_image3d(target GLenum, level int, x_offset int, y_offset int, z_offset int, width int, height int, depth int, format GLenum, data []u8, source_offset u64, length_override u32) {
	if format !in context.enabled_compressed_texture_formats_ {
		context.set_error(invalid_enum)
		return
	}
	pixels := offset_span(data, source_offset, length_override) or {
		context.set_error(invalid_value)
		return
	}
	context.webgl2_command('compressed_tex_sub_image3d', target, level, x_offset, y_offset, z_offset, width, height, depth, format, pixels.len)
}

pub fn (mut context WebGLRenderingContext) delete_transform_feedback(feedback ?&WebGLTransformFeedback) {
	if value := feedback {
		mut mutable_value := unsafe { &WebGLTransformFeedback(value) }
		handle_result := mutable_value.object.handle_for_deletion(context.identity(), context.context_generation_) or {
			context.set_error(invalid_operation)
			return
		}
		if !handle_result.has_value {
			return
		}
		handle := handle_result.value
		context.transform_feedbacks.delete(handle)
		if current := context.current_transform_feedback {
			if current.object.handle_ == handle {
				context.current_transform_feedback = none
			}
		}
		context.webgl2_command('delete_transform_feedback', handle)
	}
}

pub fn (mut context WebGLRenderingContext) draw_buffers(buffers []GLenum) {
	mut args := buffers.map(i64(it))
	context.webgl2_command('draw_buffers', ...args)
}

pub fn (mut context WebGLRenderingContext) draw_range_elements(mode GLenum, start GLuint, end GLuint, count int, type_ GLenum, offset i64) {
	if count < 0 || offset < 0 || start > end {
		context.set_error(invalid_value)
		return
	}
	context.webgl2_command('draw_range_elements', mode, start, end, count, type_, offset)
}

pub fn (mut context WebGLRenderingContext) framebuffer_texture_layer(target GLenum, attachment GLenum, texture ?&WebGLTexture, level int, layer int) {
	handle := if value := texture {
		if !context.owns(&value.object) {
			context.set_error(invalid_operation)
			return
		}
		value.object.handle_
	} else {
		GLuint(0)
	}
	context.webgl2_command('framebuffer_texture_layer', target, attachment, handle, level, layer)
}

pub fn (mut context WebGLRenderingContext) get_internalformat_parameter(target GLenum, internal_format GLenum, pname GLenum) WebGLParameterValue {
	context.webgl2_command('get_internalformat_parameter', target, internal_format, pname)
	return WebGLParameterValue{ kind: .integers, integers: [i64(0)] }
}

pub fn (mut context WebGLRenderingContext) get_sync_parameter(sync &WebGLSync, pname GLenum) WebGLParameterValue {
	if !context.owns(&sync.object) {
		context.set_error(invalid_operation)
		return WebGLParameterValue{}
	}
	return WebGLParameterValue{kind: .integer, integer: context.native.native_sync_parameter(sync.native_handle_, pname)}
}

pub fn (context &WebGLRenderingContext) get_uniform_indices(_ &WebGLProgram, names []string) []GLuint {
	return names.map(GLuint(it.hash() & 0x7fff))
}

pub fn (context &WebGLRenderingContext) get_active_uniforms(_ &WebGLProgram, indices []GLuint, _ GLenum) []int {
	return indices.map(int(it))
}

pub fn (context &WebGLRenderingContext) get_uniform_block_index(_ &WebGLProgram, name string) GLuint {
	return if name == '' { GLuint(-1) } else { GLuint(name.hash() & 0x7fff) }
}

pub fn (context &WebGLRenderingContext) get_active_uniform_block_parameter(_ &WebGLProgram, index GLuint, _ GLenum) WebGLParameterValue {
	return WebGLParameterValue{ kind: .integer, integer: index }
}

pub fn (_ &WebGLRenderingContext) get_active_uniform_block_name(_ &WebGLProgram, index GLuint) string {
	return 'uniform_block_${index}'
}

pub fn (mut context WebGLRenderingContext) invalidate_framebuffer(target GLenum, attachments []GLenum) {
	context.webgl2_command('invalidate_framebuffer', target, attachments.len)
}

pub fn (mut context WebGLRenderingContext) invalidate_sub_framebuffer(target GLenum, attachments []GLenum, x int, y int, width int, height int) {
	context.webgl2_command('invalidate_sub_framebuffer', target, attachments.len, x, y, width, height)
}

pub fn (mut context WebGLRenderingContext) read_buffer(source GLenum) {
	context.webgl2_command('read_buffer', source)
}

pub fn (mut context WebGLRenderingContext) renderbuffer_storage_multisample(target GLenum, samples int, internal_format GLenum, width int, height int) {
	if samples < 0 || width < 0 || height < 0 {
		context.set_error(invalid_value)
		return
	}
	mut buffer := context.renderbuffers[context.bound_renderbuffer] or {
		context.set_error(invalid_operation)
		return
	}
	buffer.samples_ = samples
	buffer.internal_format_ = internal_format
	buffer.width_ = width
	buffer.height_ = height
	context.webgl2_command('renderbuffer_storage_multisample', target, samples, internal_format, width, height)
}

pub fn (mut context WebGLRenderingContext) tex_storage2d(target GLenum, levels int, internal_format GLenum, width int, height int) {
	if levels <= 0 || width <= 0 || height <= 0 {
		context.set_error(invalid_value)
		return
	}
	context.webgl2_command('tex_storage2d', target, levels, internal_format, width, height)
}

pub fn (mut context WebGLRenderingContext) tex_storage3d(target GLenum, levels int, internal_format GLenum, width int, height int, depth int) {
	if levels <= 0 || width <= 0 || height <= 0 || depth <= 0 {
		context.set_error(invalid_value)
		return
	}
	context.webgl2_command('tex_storage3d', target, levels, internal_format, width, height, depth)
}

pub fn (mut context WebGLRenderingContext) tex_image3d(target GLenum, level int, internal_format GLenum, width int, height int, depth int, border int, format GLenum, type_ GLenum, pixels []u8) {
	if width < 0 || height < 0 || depth < 0 || border != 0 {
		context.set_error(invalid_value)
		return
	}
	context.webgl2_command('tex_image3d', target, level, internal_format, width, height, depth, border, format, type_, pixels.len)
}

pub fn (mut context WebGLRenderingContext) tex_sub_image3d(target GLenum, level int, x_offset int, y_offset int, z_offset int, width int, height int, depth int, format GLenum, type_ GLenum, pixels []u8) {
	if width < 0 || height < 0 || depth < 0 {
		context.set_error(invalid_value)
		return
	}
	context.webgl2_command('tex_sub_image3d', target, level, x_offset, y_offset, z_offset, width, height, depth, format, type_, pixels.len)
}

pub fn (mut context WebGLRenderingContext) transform_feedback_varyings(program &WebGLProgram, varyings []string, buffer_mode GLenum) {
	if !context.owns(&program.object) {
		context.set_error(invalid_operation)
		return
	}
	context.webgl2_command('transform_feedback_varyings', program.object.handle_, varyings.len, buffer_mode)
}

pub fn (mut context WebGLRenderingContext) uniform_block_binding(program &WebGLProgram, block_index GLuint, binding GLuint) {
	if !context.owns(&program.object) {
		context.set_error(invalid_operation)
		return
	}
	context.webgl2_command('uniform_block_binding', program.object.handle_, block_index, binding)
}

fn uints_to_floats(values []u32) []f32 {
	return values.map(f32(it))
}

pub fn (mut context WebGLRenderingContext) uniform1ui(location ?&WebGLUniformLocation, x u32) {
 context.uniform_uints(location, [x], 1)
}

pub fn (mut context WebGLRenderingContext) uniform2ui(location ?&WebGLUniformLocation, x u32, y u32) {
 context.uniform_uints(location, [x, y], 2)
}

pub fn (mut context WebGLRenderingContext) uniform3ui(location ?&WebGLUniformLocation, x u32, y u32, z u32) {
 context.uniform_uints(location, [x, y, z], 3)
}

pub fn (mut context WebGLRenderingContext) uniform4ui(location ?&WebGLUniformLocation, x u32, y u32, z u32, w u32) {
 context.uniform_uints(location, [x, y, z, w], 4)
}

pub fn (mut context WebGLRenderingContext) uniform1uiv(location ?&WebGLUniformLocation, values []u32) {
 context.uniform_uints(location, values, 1)
}

pub fn (mut context WebGLRenderingContext) uniform2uiv(location ?&WebGLUniformLocation, values []u32) {
 context.uniform_uints(location, values, 2)
}

pub fn (mut context WebGLRenderingContext) uniform3uiv(location ?&WebGLUniformLocation, values []u32) {
 context.uniform_uints(location, values, 3)
}

pub fn (mut context WebGLRenderingContext) uniform4uiv(location ?&WebGLUniformLocation, values []u32) {
 context.uniform_uints(location, values, 4)
}

pub fn (mut context WebGLRenderingContext) uniform_matrix3x2fv(location ?&WebGLUniformLocation, transpose bool, values []f32) {
	context.uniform_matrix(location, transpose, values, 3, 2)
}

pub fn (mut context WebGLRenderingContext) uniform_matrix4x2fv(location ?&WebGLUniformLocation, transpose bool, values []f32) {
	context.uniform_matrix(location, transpose, values, 4, 2)
}

pub fn (mut context WebGLRenderingContext) uniform_matrix2x3fv(location ?&WebGLUniformLocation, transpose bool, values []f32) {
	context.uniform_matrix(location, transpose, values, 2, 3)
}

pub fn (mut context WebGLRenderingContext) uniform_matrix4x3fv(location ?&WebGLUniformLocation, transpose bool, values []f32) {
	context.uniform_matrix(location, transpose, values, 4, 3)
}

pub fn (mut context WebGLRenderingContext) uniform_matrix2x4fv(location ?&WebGLUniformLocation, transpose bool, values []f32) {
	context.uniform_matrix(location, transpose, values, 2, 4)
}

pub fn (mut context WebGLRenderingContext) uniform_matrix3x4fv(location ?&WebGLUniformLocation, transpose bool, values []f32) {
	context.uniform_matrix(location, transpose, values, 3, 4)
}

pub fn (mut context WebGLRenderingContext) vertex_attrib_i4i(index GLuint, x int, y int, z int, w int) {
	context.vertex_attrib_values_[index] = [f32(x), f32(y), f32(z), f32(w)]
}

pub fn (mut context WebGLRenderingContext) vertex_attrib_i4iv(index GLuint, values []int) {
	if values.len >= 4 {
		context.vertex_attrib_i4i(index, values[0], values[1], values[2], values[3])
	} else {
		context.set_error(invalid_value)
	}
}

pub fn (mut context WebGLRenderingContext) vertex_attrib_i4ui(index GLuint, x u32, y u32, z u32, w u32) {
	context.vertex_attrib_values_[index] = [f32(x), f32(y), f32(z), f32(w)]
}

pub fn (mut context WebGLRenderingContext) vertex_attrib_i4uiv(index GLuint, values []u32) {
	if values.len >= 4 {
		context.vertex_attrib_i4ui(index, values[0], values[1], values[2], values[3])
	} else {
		context.set_error(invalid_value)
	}
}

pub fn (mut context WebGLRenderingContext) vertex_attrib_i_pointer(index GLuint, size int, type_ GLenum, stride int, offset i64) {
	if !context.require_webgl2() {
		return
	}
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
		stride: stride
		offset: offset
		integer: true
	}
	context.command('vertex_attrib_i_pointer', index, size, type_, stride, offset)
}

pub fn (mut context WebGLRenderingContext) vertex_attrib_divisor(index GLuint, divisor GLuint) {
	if !context.require_webgl2() {
		return
	}
	state := context.vertex_attrib_states_[index] or { VertexAttribState{} }
	context.vertex_attrib_states_[index] = VertexAttribState{
		...state
		divisor: divisor
	}
	context.command('vertex_attrib_divisor', index, divisor)
}
