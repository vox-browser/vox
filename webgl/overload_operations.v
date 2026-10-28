// Copyright (c) 2026, Ladybird contributors
// Copyright (c) 2024-2025, Aliaksandr Kalenik <kalenik.aliaksandr@gmail.com>
// Copyright (c) 2024-2025, Luke Wilde <luke@ladybird.org>
// Copyright (c) 2025, Jelle Raaijmakers <jelle@ladybird.org>
// Copyright (c) 2025, Undefine <undefine@undefine.pl>
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
	context.native.make_current()
	if internal_format !in context.enabled_compressed_texture_formats_ {
		context.set_error(invalid_enum)
		return
	}
	context.command('compressed_tex_image2d', target, level, internal_format, width, height, border, data.len)
	C.vox_gl_compressed_tex_image2d(target,level,internal_format,width,height,border,data.len,data.data)
}

pub fn (mut context WebGLRenderingContext) compressed_tex_sub_image2d(target GLenum, level int, x_offset int, y_offset int, width int, height int, format GLenum, data []u8) {
	context.native.make_current()
	if format !in context.enabled_compressed_texture_formats_ {
		context.set_error(invalid_enum)
		return
	}
	context.command('compressed_tex_sub_image2d', target, level, x_offset, y_offset, width, height, format, data.len)
	C.vox_gl_compressed_tex_sub_image2d(target,level,x_offset,y_offset,width,height,format,data.len,data.data)
}

pub fn (mut context WebGLRenderingContext) tex_image2d(target GLenum, level int, internal_format GLenum, width int, height int, border int, format GLenum, type_ GLenum, pixels []u8) {
	context.native.make_current()
	texture_data := context.texture_data_for_2d_upload(pixels, width, height, format, type_) or {
		context.set_error(invalid_operation)
		return
	}
	context.command('tex_image2d', target, level, internal_format, width, height, border, format, type_, texture_data.len)
	C.vox_gl_tex_image2d(target, level, internal_format, width, height, border, format, type_, texture_data.len, texture_data.data)
}

pub fn (mut context WebGLRenderingContext) tex_sub_image2d(target GLenum, level int, x_offset int, y_offset int, width int, height int, format GLenum, type_ GLenum, pixels []u8) {
	context.native.make_current()
	texture_data := context.texture_data_for_2d_upload(pixels, width, height, format, type_) or {
		context.set_error(invalid_operation)
		return
	}
	context.command('tex_sub_image2d', target, level, x_offset, y_offset, width, height, format, type_, texture_data.len)
	C.vox_gl_tex_sub_image2d(target, level, x_offset, y_offset, width, height, format, type_, texture_data.len, texture_data.data)
}

pub fn (mut context WebGLRenderingContext) read_pixels(x int, y int, width int, height int, format GLenum, type_ GLenum) []u8 {
	if width < 0 || height < 0 {
		context.set_error(invalid_value)
		return []u8{}
	}
	context.command('read_pixels', x, y, width, height, format, type_)
	mut alignment := 0
	C.vox_gl_int_parameter(pack_alignment, &alignment)
	capacity := required_2d_texture_data_size(width, height, format, type_, PixelUnpackState{alignment: u64(alignment)}) or {
 context.set_error(invalid_enum); return []u8{}
 }
 if capacity > u64(max_int) { context.set_error(out_of_memory); return []u8{} }
 mut data := []u8{len: int(capacity)}
 written := C.vox_gl_read_pixels(x, y, width, height, format, type_, data.len, data.data)
 if written <= 0 { return []u8{} }
 return data[..written].clone()
}

// WebGL{,2}RenderingContextOverloads::read_pixels: the destination view's
// capacity and element offset reach ANGLE's robust read, before any write-back.
pub fn (mut context WebGLRenderingContext) read_pixels_into(x int, y int, width int, height int, format GLenum, type_ GLenum, mut pixels []u8, dst_offset u64, element_size u64) {
	context.native.make_current()
	if context.version == .webgl2 && pixel_pack_buffer in context.bound_buffers {
		context.set_error(invalid_operation)
		return
	}
	if element_size == 0 || dst_offset > u64(pixels.len) / element_size {
		context.set_error(invalid_operation)
		return
	}
	byte_offset := int(dst_offset * element_size)
	context.command('read_pixels', x, y, width, height, format, type_)
	written := C.vox_gl_read_pixels(x, y, width, height, format, type_, pixels.len - byte_offset, unsafe { &u8(pixels.data) + byte_offset })
	if written < 0 || written > pixels.len - byte_offset { context.set_error(invalid_operation) }
}

pub fn (mut context WebGLRenderingContext) read_pixels_null() {
	// The WebGL2 nullable overload returns before delegating to its view body.
	if context.version == .webgl1 { context.native.make_current() }
	context.set_error(invalid_value)
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
 context.native.make_current()
 value := location or { return }
 value.handle(context.current_program) or { context.set_error(invalid_operation); return }
 if values.len % (columns * rows) != 0 { context.set_error(invalid_value); return }
 if columns != rows && !context.require_webgl2() { return }
	C.vox_gl_uniform_matrix(int(value.handle_), columns, rows, values.len / (columns * rows), int(transpose), values.data)
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

fn (mut context WebGLRenderingContext) indexed_buffer_handle(target GLenum, buffer ?&WebGLBuffer) ?GLuint {
    value := buffer or { return GLuint(0) }
    if !context.owns(&value.object) { context.set_error(invalid_operation); return none }
    mut mutable_value := unsafe { &WebGLBuffer(value) }
    if !mutable_value.is_compatible_with(target) { context.set_error(invalid_operation); return none }
    return value.object.native_handle_
}

pub fn (mut context WebGLRenderingContext) bind_buffer_base(target GLenum, index GLuint, buffer ?&WebGLBuffer) {
    context.native.make_current()
    if !context.require_webgl2() { return }
    native_handle := context.indexed_buffer_handle(target,buffer) or { return }
    context.command('bind_buffer_base',target,index,if value := buffer { value.object.handle_ } else { 0 })
    C.vox_gl_bind_buffer_base(target,index,native_handle)
}

pub fn (mut context WebGLRenderingContext) bind_buffer_range(target GLenum, index GLuint, buffer ?&WebGLBuffer, offset i64, size i64) {
    context.native.make_current()
    if !context.require_webgl2() { return }
    native_handle := context.indexed_buffer_handle(target,buffer) or { return }
    context.webgl2_command('bind_buffer_range',target,index,if value := buffer { value.object.handle_ } else { 0 },offset,size)
    C.vox_gl_bind_buffer_range(target,index,native_handle,offset,size)
}

pub fn (mut context WebGLRenderingContext) blit_framebuffer(source_x0 int, source_y0 int, source_x1 int, source_y1 int, destination_x0 int, destination_y0 int, destination_x1 int, destination_y1 int, mask GLenum, filter GLenum) {
	context.webgl2_command('blit_framebuffer', source_x0, source_y0, source_x1, source_y1, destination_x0, destination_y0, destination_x1, destination_y1, mask, filter)
}

fn (mut context WebGLRenderingContext) validate_clear_buffer_values(buffer GLenum, length int) bool {
    if !context.require_webgl2() { return false }
    context.native.make_current()
    context.native.notify_content_will_change()
    match buffer {
        GLenum(0x1800) { if length < 4 { context.set_error(invalid_value); return false } }
        GLenum(0x1801), GLenum(0x1802) { if length < 1 { context.set_error(invalid_value); return false } }
        else { context.set_error(invalid_enum); return false }
    }
    return true
}

pub fn (mut context WebGLRenderingContext) clear_bufferfv(buffer GLenum, draw_buffer int, values []f32) {
    if !context.validate_clear_buffer_values(buffer,values.len) { return }
    context.webgl2_command('clear_bufferfv',buffer,draw_buffer,values.len)
    C.vox_gl_clear_buffer_floats(buffer,draw_buffer,values.data)
}

pub fn (mut context WebGLRenderingContext) clear_bufferiv(buffer GLenum, draw_buffer int, values []int) {
    if !context.validate_clear_buffer_values(buffer,values.len) { return }
    context.webgl2_command('clear_bufferiv',buffer,draw_buffer,values.len)
    C.vox_gl_clear_buffer_ints(buffer,draw_buffer,values.data)
}

pub fn (mut context WebGLRenderingContext) clear_bufferuiv(buffer GLenum, draw_buffer int, values []u32) {
    if !context.validate_clear_buffer_values(buffer,values.len) { return }
    context.webgl2_command('clear_bufferuiv',buffer,draw_buffer,values.len)
    C.vox_gl_clear_buffer_uints(buffer,draw_buffer,values.data)
}

pub fn (mut context WebGLRenderingContext) clear_bufferfi(buffer GLenum, draw_buffer int, depth f32, stencil int) {
    if !context.require_webgl2() { return }
    context.webgl2_command('clear_bufferfi',buffer,draw_buffer,i64(depth),stencil)
    context.native.notify_content_will_change()
    C.vox_gl_clear_buffer_depth_stencil(buffer,draw_buffer,depth,stencil)
}

pub fn (mut context WebGLRenderingContext) compressed_tex_sub_image3d(target GLenum, level int, x_offset int, y_offset int, z_offset int, width int, height int, depth int, format GLenum, data []u8, source_offset u64, length_override u32) {
	context.native.make_current()
	if format !in context.enabled_compressed_texture_formats_ {
		context.set_error(invalid_enum)
		return
	}
	pixels := offset_span(data, source_offset, length_override) or {
		context.set_error(invalid_value)
		return
	}
	context.webgl2_command('compressed_tex_sub_image3d', target, level, x_offset, y_offset, z_offset, width, height, depth, format, pixels.len)
	C.vox_gl_compressed_tex_sub_image3d(target,level,x_offset,y_offset,z_offset,width,height,depth,format,pixels.len,pixels.data)
}

pub fn (mut context WebGLRenderingContext) delete_transform_feedback(feedback ?&WebGLTransformFeedback) {
	context.native.make_current()
	if value := feedback {
		mut mutable_value := unsafe { &WebGLTransformFeedback(value) }
		handle_result := mutable_value.object.handle_for_deletion(context.identity(), context.context_generation_) or {
			context.set_error(invalid_operation)
			return
		}
		if !handle_result.has_value {
			return
		}
		handle := value.object.bookkeeping_id()
		context.transform_feedbacks.delete(handle)
		context.webgl2_command('delete_transform_feedback', handle)
		C.vox_gl_delete_object(8,value.object.native_handle_)
	}
}

pub fn (mut context WebGLRenderingContext) draw_buffers(buffers []GLenum) {
	mut args := buffers.map(i64(it))
	context.webgl2_command('draw_buffers', ...args)
}

pub fn (mut context WebGLRenderingContext) draw_range_elements(mode GLenum, start GLuint, end GLuint, count int, type_ GLenum, offset i64) {
	context.native.make_current()
	if !context.require_webgl2() { return }
	context.native.notify_painting_surface_content_will_change()
	context.native.did_update_canvas_content()
	context.native.dispatch('draw_range_elements', mode, start, end, count, type_, offset)
}

pub fn (mut context WebGLRenderingContext) framebuffer_texture_layer(target GLenum, attachment GLenum, texture ?&WebGLTexture, level int, layer int) {
	context.native.make_current()
	if !context.require_webgl2() { return }
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
	C.vox_gl_framebuffer_texture_layer(target,attachment,if value:=texture {value.object.native_handle_} else {0},level,layer)
}

pub fn (mut context WebGLRenderingContext) get_internalformat_parameter(target GLenum, internal_format GLenum, pname GLenum) WebGLParameterValue {
    if !context.require_webgl2() { return WebGLParameterValue{} }
    context.native.make_current()
    if pname != samples { context.set_error(invalid_enum); return WebGLParameterValue{} }
    mut count := 0
    C.vox_gl_internalformat_parameter(target,internal_format,num_sample_counts,1,&count)
    mut values := []int{len: if count > 0 { count } else { 0 }}
    C.vox_gl_internalformat_parameter(target,internal_format,samples,values.len,values.data)
    return WebGLParameterValue{kind:.integers, integers:values.map(i64(it))}
}

pub fn (mut context WebGLRenderingContext) get_sync_parameter(sync &WebGLSync, pname GLenum) WebGLParameterValue {
	sync.sync_handle(context.identity(), context.context_generation_) or {
		context.set_error(invalid_operation)
		return WebGLParameterValue{}
	}
	return WebGLParameterValue{kind: .integer, integer: context.native.native_sync_parameter(sync.native_handle_, pname)}
}

pub fn (mut context WebGLRenderingContext) get_uniform_indices(program &WebGLProgram, names []string) []GLuint {
    // Retain the existing typed convenience return shape; browser bindings
    // use the source nullable operation below.
    return context.get_uniform_indices_nullable(program, names) or { []GLuint{} }
}

// WebGL2RenderingContextImpl::get_uniform_indices returns OptionalNone on a
// failed program handle, distinct from a successful empty name list.
pub fn (mut context WebGLRenderingContext) get_uniform_indices_nullable(program &WebGLProgram, names []string) ?[]GLuint {
	context.native.make_current()
    if !context.require_webgl2() { return none }
    if !context.owns(&program.object) { context.set_error(invalid_operation); return none }
    pointers := names.map(it.str)
    mut result := []GLuint{len:names.len}
    C.vox_gl_uniform_indices(program.object.native_handle_,names.len,pointers.data,result.data)
    return result
}

pub fn (mut context WebGLRenderingContext) get_active_uniforms(program &WebGLProgram, indices []GLuint, pname GLenum) WebGLParameterValue {
	context.native.make_current()
    if !context.require_webgl2() { return WebGLParameterValue{} }
    if !context.owns(&program.object) { context.set_error(invalid_operation); return WebGLParameterValue{kind:.undefined_} }
    mut result := []int{len:indices.len}
    C.vox_gl_active_uniforms(program.object.native_handle_,indices.len,indices.data,pname,result.data)
    // Source validates pname in its per-element result loop, after GL. An
    // empty index vector skips that switch and still creates an empty Array.
    if indices.len == 0 { return WebGLParameterValue{kind:.integers} }
    if pname == uniform_is_row_major { return WebGLParameterValue{kind:.booleans,booleans:result.map(it == 1)} }
    if pname in [uniform_type,uniform_size,uniform_block_index,uniform_offset,uniform_array_stride,uniform_matrix_stride] {
        return WebGLParameterValue{kind:.integers,integers:result.map(i64(it))}
    }
    context.set_error(invalid_enum)
    return WebGLParameterValue{}
}

pub fn (mut context WebGLRenderingContext) get_uniform_block_index(program &WebGLProgram, name string) GLuint {
	context.native.make_current()
    if !context.require_webgl2() { return GLuint(0xffff_ffff) }
    if !context.owns(&program.object) { context.set_error(invalid_operation); return GLuint(0xffff_ffff) }
    result := C.vox_gl_uniform_block_index(program.object.native_handle_,name.str)
    return result
}

fn (mut context WebGLRenderingContext) uniform_block_parameter(program &WebGLProgram, index GLuint, pname GLenum) int {
    mut result := 0
    C.vox_gl_uniform_block_parameter(program.object.native_handle_,index,pname,1,&result)
    return result
}

pub fn (mut context WebGLRenderingContext) get_active_uniform_block_parameter(program &WebGLProgram, index GLuint, pname GLenum) WebGLParameterValue {
	context.native.make_current()
    if !context.require_webgl2() { return WebGLParameterValue{} }
    if !context.owns(&program.object) { context.set_error(invalid_operation); return WebGLParameterValue{} }
    if pname in [uniform_block_binding,uniform_block_data_size,uniform_block_active_uniforms] {
        return integer_parameter(context.uniform_block_parameter(program,index,pname))
    }
    if pname in [uniform_block_referenced_by_vertex_shader,uniform_block_referenced_by_fragment_shader] {
        return boolean_parameter(context.uniform_block_parameter(program,index,pname) == 1)
    }
    if pname == uniform_block_active_uniform_indices {
        count := context.uniform_block_parameter(program,index,uniform_block_active_uniforms)
        mut indices := []int{len: if count>0 { count } else { 0 }}
        C.vox_gl_uniform_block_parameter(program.object.native_handle_,index,pname,indices.len,indices.data)
        return WebGLParameterValue{kind:.integers,integers:indices.map(i64(it))}
    }
    context.set_error(invalid_enum)
    return WebGLParameterValue{}
}

pub fn (mut context WebGLRenderingContext) get_active_uniform_block_name(program &WebGLProgram, index GLuint) ?string {
	context.native.make_current()
    if !context.require_webgl2() { return none }
    if !context.owns(&program.object) { context.set_error(invalid_operation); return none }
    length := context.uniform_block_parameter(program,index,uniform_block_name_length)
    if length<=0 { return '' }
    mut name := []u8{len:length}
    C.vox_gl_uniform_block_name(program.object.native_handle_,index,length,name.data)
    return null_terminated_string(name)
}

pub fn (mut context WebGLRenderingContext) invalidate_framebuffer(target GLenum, attachments []GLenum) {
	if !context.require_webgl2() { return }
	context.webgl2_command('invalidate_framebuffer', target, attachments.len)
	context.native.notify_content_will_change()
	C.vox_gl_invalidate_framebuffer(target,attachments.len,attachments.data)
}

pub fn (mut context WebGLRenderingContext) invalidate_sub_framebuffer(target GLenum, attachments []GLenum, x int, y int, width int, height int) {
	if !context.require_webgl2() { return }
	context.webgl2_command('invalidate_sub_framebuffer', target, attachments.len, x, y, width, height)
	context.native.notify_content_will_change()
	C.vox_gl_invalidate_sub_framebuffer(target,attachments.len,attachments.data,x,y,width,height)
}

pub fn (mut context WebGLRenderingContext) read_buffer(source GLenum) {
	context.webgl2_command('read_buffer', source)
}

pub fn (mut context WebGLRenderingContext) renderbuffer_storage_multisample(target GLenum, samples int, internal_format GLenum, width int, height int) {
	context.native.make_current()
	context.webgl2_command('renderbuffer_storage_multisample', target, samples, internal_format, width, height)
}

pub fn (mut context WebGLRenderingContext) tex_storage2d(target GLenum, levels int, internal_format GLenum, width int, height int) {
	context.native.make_current()
	context.webgl2_command('tex_storage2d', target, levels, internal_format, width, height)
}

pub fn (mut context WebGLRenderingContext) tex_storage3d(target GLenum, levels int, internal_format GLenum, width int, height int, depth int) {
	context.native.make_current()
	context.webgl2_command('tex_storage3d', target, levels, internal_format, width, height, depth)
}

pub fn (mut context WebGLRenderingContext) tex_image3d(target GLenum, level int, internal_format GLenum, width int, height int, depth int, border int, format GLenum, type_ GLenum, pixels []u8) {
	context.native.make_current()
	if !context.require_webgl2() { return }
	context.webgl2_command('tex_image3d', target, level, internal_format, width, height, depth, border, format, type_, pixels.len)
	C.vox_gl_tex_image3d(target,level,int(internal_format),width,height,depth,border,format,type_,pixels.len,pixels.data)
}

pub fn (mut context WebGLRenderingContext) tex_sub_image3d(target GLenum, level int, x_offset int, y_offset int, z_offset int, width int, height int, depth int, format GLenum, type_ GLenum, pixels []u8) {
	context.native.make_current()
	if !context.require_webgl2() { return }
	context.webgl2_command('tex_sub_image3d', target, level, x_offset, y_offset, z_offset, width, height, depth, format, type_, pixels.len)
	C.vox_gl_tex_sub_image3d(target,level,x_offset,y_offset,z_offset,width,height,depth,format,type_,pixels.len,pixels.data)
}

pub fn (mut context WebGLRenderingContext) transform_feedback_varyings(program &WebGLProgram, varyings []string, buffer_mode GLenum) {
	context.native.make_current()
	if !context.owns(&program.object) {
		context.set_error(invalid_operation)
		return
	}
	if !context.require_webgl2() { return }
	context.webgl2_command('transform_feedback_varyings', program.object.handle_, varyings.len, buffer_mode)
	names := varyings.map(voidptr(it.str))
	C.vox_gl_transform_feedback_varyings(program.object.native_handle_,names.len,names.data,buffer_mode)
}

pub fn (mut context WebGLRenderingContext) uniform_block_binding(program &WebGLProgram, block_index GLuint, binding GLuint) {
	if !context.owns(&program.object) {
		context.set_error(invalid_operation)
		return
	}
	if !context.require_webgl2() { return }
	context.webgl2_command('uniform_block_binding', program.object.handle_, block_index, binding)
	C.vox_gl_uniform_block_binding(program.object.native_handle_,block_index,binding)
}

pub fn (mut context WebGLRenderingContext) uniform1ui(location ?&WebGLUniformLocation, x u32) {
	handle := context.scalar_uniform_location(location) or { return }
	if !context.require_webgl2() { return }
	C.vox_gl_uniform1ui(int(handle), x)
}

pub fn (mut context WebGLRenderingContext) uniform2ui(location ?&WebGLUniformLocation, x u32, y u32) {
	handle := context.scalar_uniform_location(location) or { return }
	if !context.require_webgl2() { return }
	C.vox_gl_uniform2ui(int(handle), x, y)
}

pub fn (mut context WebGLRenderingContext) uniform3ui(location ?&WebGLUniformLocation, x u32, y u32, z u32) {
	handle := context.scalar_uniform_location(location) or { return }
	if !context.require_webgl2() { return }
	C.vox_gl_uniform3ui(int(handle), x, y, z)
}

pub fn (mut context WebGLRenderingContext) uniform4ui(location ?&WebGLUniformLocation, x u32, y u32, z u32, w u32) {
	handle := context.scalar_uniform_location(location) or { return }
	if !context.require_webgl2() { return }
	C.vox_gl_uniform4ui(int(handle), x, y, z, w)
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
    if !context.require_webgl2() { return }
    context.native.make_current()
    C.vox_gl_vertex_attrib_i4i(index, x, y, z, w)
}

pub fn (mut context WebGLRenderingContext) vertex_attrib_i4iv(index GLuint, values []int) {
	if values.len < 4 {
		context.set_error(invalid_value)
		return
	}
	if !context.require_webgl2() {
		return
	}
	context.native.make_current()
	C.vox_gl_vertex_attrib_ints(index, values.data)
}

pub fn (mut context WebGLRenderingContext) vertex_attrib_i4ui(index GLuint, x u32, y u32, z u32, w u32) {
    if !context.require_webgl2() { return }
    context.native.make_current()
    C.vox_gl_vertex_attrib_i4ui(index, x, y, z, w)
}

pub fn (mut context WebGLRenderingContext) vertex_attrib_i4uiv(index GLuint, values []u32) {
	if values.len < 4 {
		context.set_error(invalid_value)
		return
	}
	if !context.require_webgl2() {
		return
	}
	context.native.make_current()
	C.vox_gl_vertex_attrib_uints(index, values.data)
}

pub fn (mut context WebGLRenderingContext) vertex_attrib_i_pointer(index GLuint, size int, type_ GLenum, stride int, offset i64) {
	if !context.require_webgl2() {
		return
	}
	context.command('vertex_attrib_i_pointer', index, size, type_, stride, offset)
}

pub fn (mut context WebGLRenderingContext) vertex_attrib_divisor(index GLuint, divisor GLuint) {
	if !context.require_webgl2() {
		return
	}
	context.command('vertex_attrib_divisor', index, divisor)
}

// WebGL2RenderingContextOverloads.cpp numeric readPixels overload and the
// host-side ReadPixelsIntoPixelPackBuffer command. GL retains packing and
// destination-buffer range validation.
pub fn (mut context WebGLRenderingContext) read_pixels_into_pixel_pack_buffer(x int, y int, width int, height int, format GLenum, type_ GLenum, offset i64) {
    context.native.make_current()
    if !context.require_webgl2() {return}
    if pixel_pack_buffer !in context.bound_buffers {context.set_error(invalid_operation);return}
    context.command('read_pixels_into_pixel_pack_buffer',x,y,width,height,format,type_,offset)
    C.vox_gl_read_pixels_to_buffer(x,y,width,height,format,type_,offset)
}
