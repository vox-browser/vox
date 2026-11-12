// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module webgl

$if macos {
	#pkgconfig --cflags egl glesv2
} $else $if windows {
	#flag @DIR/../Build/deps/windows/native/webgl.a
	#pkgconfig angleproject
} $else {
	#pkgconfig egl glesv2
}
#flag darwin -Wl,-rpath,/opt/homebrew/lib
#include "@DIR/native_egl.h"

fn C.vox_egl_create(int) voidptr
fn C.vox_egl_make_current(voidptr) int
fn C.vox_egl_destroy(voidptr)
fn C.vox_gl_fence_sync(u32, u32) voidptr
fn C.vox_gl_client_wait_sync(voidptr, u32, u64) u32
fn C.vox_gl_wait_sync(voidptr, u32, u64)
fn C.vox_gl_delete_sync(voidptr)
fn C.vox_gl_get_sync_parameter(voidptr, u32) int
fn C.vox_gl_get_error() u32
fn C.vox_gl_is_object(int,u32) int
fn C.vox_gl_string(u32) &char
fn C.vox_gl_parameter_shape(u32,int) int
fn C.vox_gl_parameter(u32,int,&f64)
fn C.vox_gl_request_extension(&char)

fn native_gl_string(name GLenum) string {
	value := C.vox_gl_string(name)
	if value == unsafe { nil } { return '' }
	return unsafe { cstring_to_vstring(value).clone() }
}

fn native_gl_extensions() []string {
	mut extensions := native_gl_string(0x1f03).split(' ').filter(it.len > 0)
	extensions << native_gl_string(0x93a8).split(' ').filter(it.len > 0)
	return extensions
}
fn C.vox_egl_free_surface(voidptr)
fn C.vox_egl_allocate_surface(voidptr, int, int, int, int) int
fn C.vox_egl_default_framebuffer(voidptr) u32
fn C.vox_egl_default_renderbuffer(voidptr) u32
fn C.vox_egl_copy_drawing_buffer(voidptr,int,int,&u8) int
fn C.vox_egl_clear_drawing_buffer(voidptr)
fn C.vox_gl_gen_object(int) u32
fn C.vox_gl_delete_object(int, u32)
fn C.vox_gl_begin_query(u32, u32)
fn C.vox_gl_end_query(u32)
fn C.vox_gl_query_parameter(u32, u32) u32
fn C.vox_gl_bind_sampler(u32, u32)
fn C.vox_gl_sampler_parameteri(u32, u32, int)
fn C.vox_gl_sampler_parameterf(u32, u32, f32)
fn C.vox_gl_sampler_parameter(u32, u32) f32
fn C.vox_gl_bind_vertex_array(u32, int)
fn C.vox_gl_is_vertex_array(u32, int) int
fn C.vox_gl_vertex_attrib_parameter(u32, u32) int
fn C.vox_gl_vertex_attrib_float_parameter(u32, &f32)
fn C.vox_gl_vertex_attrib_offset(u32) i64
fn C.vox_gl_bind_transform_feedback(u32,u32)
fn C.vox_gl_begin_transform_feedback(u32)
fn C.vox_gl_end_transform_feedback()
fn C.vox_gl_pause_transform_feedback()
fn C.vox_gl_resume_transform_feedback()
fn C.vox_gl_transform_feedback_varyings(u32,int,voidptr,u32)
fn C.vox_gl_bind_buffer_base(u32,u32,u32)
fn C.vox_gl_bind_buffer_range(u32,u32,u32,i64,i64)
fn C.vox_gl_bind_buffer(u32, u32)
fn C.vox_gl_buffer_data(u32, i64, voidptr, u32)
fn C.vox_gl_buffer_sub_data(u32, i64, i64, voidptr)
fn C.vox_gl_copy_buffer_sub_data(u32, u32, i64, i64, i64)
fn C.vox_gl_read_buffer_sub_data(u32, i64, i64, voidptr) int
fn C.vox_gl_buffer_parameter(u32, u32) int
fn C.vox_gl_vertex_attrib_pointer(u32, int, u32, int, int, i64)
fn C.vox_gl_vertex_attrib_i_pointer(u32, int, u32, int, i64)
fn C.vox_gl_vertex_attrib1f(u32, f32)
fn C.vox_gl_vertex_attrib2f(u32, f32, f32)
fn C.vox_gl_vertex_attrib3f(u32, f32, f32, f32)
fn C.vox_gl_vertex_attrib4f(u32, f32, f32, f32, f32)
fn C.vox_gl_vertex_attrib1fv(u32, &f32)
fn C.vox_gl_vertex_attrib2fv(u32, &f32)
fn C.vox_gl_vertex_attrib3fv(u32, &f32)
fn C.vox_gl_vertex_attrib_floats(u32, &f32)
fn C.vox_gl_vertex_attrib_enable(u32, int)
fn C.vox_gl_vertex_attrib_divisor(u32, u32, int)
fn C.vox_gl_draw_arrays(u32, int, int)
fn C.vox_gl_draw_elements(u32, int, u32, i64)
fn C.vox_gl_draw_arrays_instanced(u32, int, int, int, int)
fn C.vox_gl_draw_elements_instanced(u32, int, u32, i64, int, int)
fn C.vox_gl_draw_range_elements(u32, u32, u32, int, u32, i64)
fn C.vox_gl_bind_framebuffer(u32, u32)
fn C.vox_gl_bind_renderbuffer(u32, u32)
fn C.vox_gl_bind_texture(u32, u32)
fn C.vox_gl_framebuffer_status(u32) u32
fn C.vox_gl_framebuffer_texture(u32, u32, u32, u32, int)
fn C.vox_gl_framebuffer_renderbuffer(u32, u32, u32, u32)
fn C.vox_gl_renderbuffer_storage(u32, u32, int, int)
fn C.vox_gl_tex_image2d(u32, int, int, int, int, int, u32, u32, int, voidptr)
fn C.vox_gl_compressed_tex_image2d(u32,int,u32,int,int,int,int,voidptr)
fn C.vox_gl_compressed_tex_sub_image2d(u32,int,int,int,int,int,u32,int,voidptr)
fn C.vox_gl_compressed_tex_image3d(u32,int,u32,int,int,int,int,int,voidptr)
fn C.vox_gl_compressed_tex_sub_image3d(u32,int,int,int,int,int,int,int,u32,int,voidptr)
fn C.vox_gl_tex_sub_image2d(u32, int, int, int, int, int, u32, u32, int, voidptr)
fn C.vox_gl_tex_parameteri(u32, u32, int)
fn C.vox_gl_tex_parameterf(u32, u32, f32)
fn C.vox_gl_tex_storage2d(u32,int,u32,int,int)
fn C.vox_gl_tex_storage3d(u32,int,u32,int,int,int)
fn C.vox_gl_tex_image3d(u32,int,int,int,int,int,int,u32,u32,int,voidptr)
fn C.vox_gl_tex_sub_image3d(u32,int,int,int,int,int,int,int,u32,u32,int,voidptr)
fn C.vox_gl_framebuffer_texture_layer(u32,u32,u32,int,int)
fn C.vox_gl_copy_tex_image2d(u32,int,u32,int,int,int,int,int)
fn C.vox_gl_copy_tex_sub_image2d(u32,int,int,int,int,int,int,int)
fn C.vox_gl_draw_buffers(int,&u32,int)
fn C.vox_gl_read_buffer(u32)
fn C.vox_gl_blit_framebuffer(int,int,int,int,int,int,int,int,u32,u32)
fn C.vox_gl_renderbuffer_storage_multisample(u32,int,u32,int,int)
fn C.vox_gl_invalidate_framebuffer(u32,int,&u32)
fn C.vox_gl_invalidate_sub_framebuffer(u32,int,&u32,int,int,int,int)
fn C.vox_gl_tex_parameter(u32,u32) int
fn C.vox_gl_tex_float_parameter(u32,u32) f32
fn C.vox_gl_renderbuffer_parameter(u32,u32) int
fn C.vox_gl_read_pixels(int, int, int, int, u32, u32, int, voidptr) int
fn C.vox_gl_read_pixels_to_buffer(int,int,int,int,u32,u32,i64)
fn C.vox_gl_clear_color(f32, f32, f32, f32)
fn C.vox_gl_clear_depth(f32)
fn C.vox_gl_clear_stencil(int)
fn C.vox_gl_color_mask(int, int, int, int)
fn C.vox_gl_depth_mask(int)
fn C.vox_gl_clear(u32)
fn C.vox_gl_viewport(int, int, int, int)
fn C.vox_gl_scissor(int, int, int, int)
fn C.vox_gl_enable(u32)
fn C.vox_gl_is_enabled(u32) int
fn C.vox_gl_disable(u32)
fn C.vox_gl_pixel_storei(u32, int)
fn C.vox_gl_active_texture(u32)
fn C.vox_gl_blend_color(f32,f32,f32,f32)
fn C.vox_gl_blend_equation(u32)
fn C.vox_gl_blend_equation_separate(u32,u32)
fn C.vox_gl_blend_func(u32,u32)
fn C.vox_gl_blend_func_separate(u32,u32,u32,u32)
fn C.vox_gl_cull_face(u32)
fn C.vox_gl_depth_func(u32)
fn C.vox_gl_depth_range(f32,f32)
fn C.vox_gl_finish()
fn C.vox_gl_flush()
fn C.vox_gl_front_face(u32)
fn C.vox_gl_generate_mipmap(u32)
fn C.vox_gl_hint(u32,u32)
fn C.vox_gl_line_width(f32)
fn C.vox_gl_polygon_offset(f32,f32)
fn C.vox_gl_sample_coverage(f32,int)
fn C.vox_gl_stencil_func(u32,int,u32)
fn C.vox_gl_stencil_func_separate(u32,u32,int,u32)
fn C.vox_gl_stencil_mask(u32)
fn C.vox_gl_stencil_mask_separate(u32,u32)
fn C.vox_gl_stencil_op(u32,u32,u32)
fn C.vox_gl_stencil_op_separate(u32,u32,u32,u32)
fn C.vox_gl_clear_buffer_floats(u32,int,&f32)
// GLint storage is always 32-bit, including when V's int is 64-bit.
fn C.vox_gl_clear_buffer_ints(u32,int,&i32)
fn C.vox_gl_clear_buffer_uints(u32,int,&u32)
fn C.vox_gl_clear_buffer_depth_stencil(u32,int,f32,int)
fn C.vox_gl_vertex_attrib_i4i(u32, int, int, int, int)
fn C.vox_gl_vertex_attrib_i4ui(u32, u32, u32, u32, u32)
fn C.vox_gl_vertex_attrib_ints(u32,&i32)
fn C.vox_gl_vertex_attrib_uints(u32,&u32)
fn C.vox_gl_vertex_attrib_int_parameter(u32,&i32)
fn C.vox_gl_vertex_attrib_uint_parameter(u32,&u32)
fn C.vox_gl_float_parameter(u32,&f32)
fn C.vox_gl_int_parameter(u32,&i32)
fn C.vox_gl_create_shader(u32) u32
fn C.vox_gl_create_program() u32
fn C.vox_gl_shader_source(u32, &char, int)
fn C.vox_gl_get_shader_source(u32, int, &char)
fn C.vox_gl_compile_shader(u32)
fn C.vox_gl_attach_shader(u32, u32)
fn C.vox_gl_detach_shader(u32, u32)
fn C.vox_gl_link_program(u32)
fn C.vox_gl_use_program(u32)
fn C.vox_gl_validate_program(u32)
fn C.vox_gl_delete_shader(u32)
fn C.vox_gl_delete_program(u32)
fn C.vox_gl_shader_parameter(u32, u32) int
fn C.vox_gl_shader_parameter_robust(u32, u32) int
fn C.vox_gl_program_parameter(u32, u32) int
fn C.vox_gl_program_parameter_robust(u32, u32) int
fn C.vox_gl_shader_log(u32, int, &u8)
fn C.vox_gl_program_log(u32, int, &u8)
fn C.vox_gl_uniform_location(u32, &char) int
fn C.vox_gl_attrib_location(u32, &char) int
fn C.vox_gl_bind_attrib_location(u32, u32, &char)
fn C.vox_gl_active_info(u32, u32, int, int, &u8, &i32, &u32) int
fn C.vox_gl_uniform_indices(u32,int,voidptr,&u32)
fn C.vox_gl_active_uniforms(u32,int,&u32,u32,&i32)
fn C.vox_gl_uniform_block_index(u32,&char) u32
fn C.vox_gl_uniform_block_parameter(u32,u32,u32,int,&i32)
fn C.vox_gl_uniform_block_name(u32,u32,int,&u8)
fn C.vox_gl_uniform_block_binding(u32,u32,u32)
fn C.vox_gl_internalformat_parameter(u32,u32,u32,int,&i32)
fn C.vox_gl_shader_precision(u32, u32, &i32, &i32)
fn C.vox_gl_uniform1f(int, f32)
fn C.vox_gl_uniform2f(int, f32, f32)
fn C.vox_gl_uniform3f(int, f32, f32, f32)
fn C.vox_gl_uniform4f(int, f32, f32, f32, f32)
fn C.vox_gl_uniform1i(int, int)
fn C.vox_gl_uniform2i(int, int, int)
fn C.vox_gl_uniform3i(int, int, int, int)
fn C.vox_gl_uniform4i(int, int, int, int, int)
fn C.vox_gl_uniform1ui(int, u32)
fn C.vox_gl_uniform2ui(int, u32, u32)
fn C.vox_gl_uniform3ui(int, u32, u32, u32)
fn C.vox_gl_uniform4ui(int, u32, u32, u32, u32)
fn C.vox_gl_uniform_floats(int, int, int, &f32)
fn C.vox_gl_uniform_ints(int, int, int, &i32)
fn C.vox_gl_uniform_uints(int, int, int, &u32)
fn C.vox_gl_uniform_matrix(int, int, int, int, int, &f32)
fn C.vox_gl_get_uniform_floats(u32, int, &f32)
fn C.vox_gl_get_uniform_ints(u32, int, &i32)
fn C.vox_gl_get_uniform_uints(u32, int, &u32)

fn (mut context OpenGLContext) native_fence_sync(condition GLenum, flags GLenum) voidptr {
	context.make_current()
	if !context.current_ { return unsafe { nil } }
	handle := C.vox_gl_fence_sync(condition, flags)
	return handle
}

fn (mut context OpenGLContext) native_client_wait_sync(handle voidptr, flags GLenum, _requested_timeout u64) GLenum {
	context.make_current()
	// Generated Source sync calls return a default GLenum after proxy loss.
	if !context.current_ { return GLenum(0) }
	// The actual Source compositor sync receiver overrides the wire timeout to 0.
	result := GLenum(C.vox_gl_client_wait_sync(handle, flags, 0))
	return result
}

fn (mut context OpenGLContext) native_wait_sync(handle voidptr, flags GLenum, timeout u64) {
	context.make_current()
	if !context.current_ { return }
	C.vox_gl_wait_sync(handle, flags, timeout)
}

fn (mut context OpenGLContext) native_delete_sync(handle voidptr) {
	context.make_current()
	if !context.current_ { return }
	C.vox_gl_delete_sync(handle)
}

fn (mut context OpenGLContext) native_sync_parameter(handle voidptr, pname GLenum) int {
	context.make_current()
	if !context.current_ { return 0 }
	result := C.vox_gl_get_sync_parameter(handle, pname)
	return result
}

fn (mut context OpenGLContext) native_shader_parameter(handle GLuint, pname GLenum) int {
	context.make_current()
	if !context.current_ { return 0 }
	result := C.vox_gl_shader_parameter(handle, pname)
	return result
}

// The Source public parameter getter uses the robust one-element query;
// its source/log length queries retain regular get_shaderiv separately.
fn (mut context OpenGLContext) native_shader_parameter_robust(handle GLuint, pname GLenum) int {
	context.make_current()
	if !context.current_ { return 0 }
	return C.vox_gl_shader_parameter_robust(handle, pname)
}

fn (mut context OpenGLContext) native_program_parameter(handle GLuint, pname GLenum) int {
	context.make_current()
	if !context.current_ { return 0 }
	result := C.vox_gl_program_parameter(handle, pname)
	return result
}

// Source get_program_parameter uses this robust one-element query; its
// diagnostic log length retains the regular programiv method above.
fn (mut context OpenGLContext) native_program_parameter_robust(handle GLuint, pname GLenum) int {
	context.make_current()
	if !context.current_ { return 0 }
	return C.vox_gl_program_parameter_robust(handle, pname)
}

fn (mut context OpenGLContext) native_shader_log(handle GLuint) string {
	length := context.native_shader_parameter(handle, GLenum(0x8b84))
	if length <= 0 { return '' }
	mut output := []u8{len: length}
	C.vox_gl_shader_log(handle, length, output.data)
	return output[..length - 1].bytestr()
}

// WebGLRenderingContextImpl::get_shader_source first queries the native
// GL_SHADER_SOURCE_LENGTH, including its terminator, then excludes that byte.
fn (mut context OpenGLContext) native_shader_source(handle GLuint) string {
	length := context.native_shader_parameter(handle, GLenum(0x8b88))
	if length <= 0 { return '' }
	mut output := []u8{len: length}
	C.vox_gl_get_shader_source(handle, length, output.data)
	return output[..length - 1].bytestr()
}

fn (mut context OpenGLContext) native_program_log(handle GLuint) string {
	length := context.native_program_parameter(handle, GLenum(0x8b84))
	if length <= 0 { return '' }
	mut output := []u8{len: length}
	C.vox_gl_program_log(handle, length, output.data)
	return output[..length - 1].bytestr()
}

fn (mut context OpenGLContext) native_active_info(handle GLuint, index GLuint, uniform bool) WebGLActiveInfo {
	context.make_current()
	mut name := []u8{len: 256}
	mut size := i32(0)
	mut type_ := u32(0)
	length := C.vox_gl_active_info(handle, index, int(uniform), name.len, name.data, &size, &type_)
	return WebGLActiveInfo.create(name[..length].bytestr(), GLenum(type_), int(size))
}
