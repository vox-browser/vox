module webgl

fn upstream_native_surface_viewport() [4]i32 {
	mut value := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &value[0])
	return value
}

fn test_upstream_value_factories_and_native_surface_slots() {
	mut context := WebGLRenderingContext.create(.webgl2, WebGLContextAttributes{}, [])
	assert context.context().webgl_version() == .webgl2
	context.set_size(8, 6)
	assert upstream_native_surface_viewport() == [i32(0), 0, 0, 0]!
	context.allocate_painting_surface_if_needed()
	assert context.surface()
	assert upstream_native_surface_viewport() == [i32(0), 0, 8, 6]!
	assert context.native.default_framebuffer() != 0
	assert context.native.default_renderbuffer() != 0
	context.viewport(1, 2, 3, 4)
	context.allocate_painting_surface_if_needed()
	assert upstream_native_surface_viewport() == [i32(1), 2, 3, 4]!
	context.set_size(13, 7)
	assert !context.surface()
	assert upstream_native_surface_viewport() == [i32(1), 2, 3, 4]!
	context.allocate_painting_surface_if_needed()
	assert upstream_native_surface_viewport() == [i32(0), 0, 13, 7]!
	context.native.free_surface_resources()
	assert !context.surface()

	info := WebGLActiveInfo.create('position', GLenum(0x1406), 1)
	assert info.name() == 'position'
	assert info.type_() == GLenum(0x1406)
	assert info.size() == 1
	precision := WebGLShaderPrecisionFormat.create(-127, 127, 23)
	assert precision.range_min() == -127
	assert precision.range_max() == 127
	assert precision.precision() == 23
	event := WebGLContextEvent.construct_impl('webglcontextlost', WebGLContextEventInit{
		status_message: 'lost'
	})
	assert event.status_message() == 'lost'
	assert event.time_stamp() == 0
	constructed_event := WebGLContextEvent.create_for_constructor('webglcontextrestored', WebGLContextEventInit{
		status_message: 'restored'
	}, 42.25)
	assert constructed_event.type_ == 'webglcontextrestored'
	assert constructed_event.status_message() == 'restored'
	assert constructed_event.time_stamp() == 42.25
}

fn test_upstream_texture_renderbuffer_and_framebuffer_state() {
	mut context := WebGLRenderingContext.create(.webgl2, WebGLContextAttributes{}, [])
	mut texture := WebGLTexture.create(mut context)
	context.bind_texture(texture_2d, texture)
	context.tex_parameteri(texture_2d, texture_min_filter, 0x2601)
	context.tex_image2d(texture_2d, 0, 0x1908, 2, 3, 0, 0x1908, 0x1401, []u8{len: 24})
	image_framebuffer := context.create_framebuffer()
	context.bind_framebuffer(framebuffer, image_framebuffer)
	context.framebuffer_texture2d(framebuffer, color_attachment0, texture_2d, texture, 0)
	assert context.check_framebuffer_status(framebuffer) == 0x8cd5
	assert context.read_pixels(0, 0, 2, 3, rgba, unsigned_byte) == []u8{len: 24}
	assert context.get_tex_parameter(texture_2d, texture_min_filter).integer == 0x2601

	mut renderbuffer_object := WebGLRenderbuffer.create(mut context)
	context.bind_renderbuffer(renderbuffer, renderbuffer_object)
	context.renderbuffer_storage(renderbuffer, 0x8058, 4, 5)
	assert context.get_renderbuffer_parameter(renderbuffer, 0x8d42).integer == 4
	mut framebuffer_object := WebGLFramebuffer.create(mut context)
	context.bind_framebuffer(framebuffer, framebuffer_object)
	context.framebuffer_texture2d(framebuffer, 0x8ce0, texture_2d, texture, 0)
	attachment := framebuffer_object.attachment(color_attachment0) or { panic('attachment') }
	assert attachment.texture or { panic('texture attachment') } == texture
	assert context.check_framebuffer_status(framebuffer) == GLenum(0x8cd5)

	context.delete_texture(texture)
	assert !context.is_texture(texture)
	assert texture_2d !in context.bound_textures
}

fn test_upstream_uniform_vectors_matrices_and_webgl2_validation() {
	mut context := WebGLRenderingContext.create(.webgl2, WebGLContextAttributes{}, [])
	mut vertex := WebGLShader.create(mut context, vertex_shader) or { panic('vertex shader') }
	mut fragment := WebGLShader.create(mut context, fragment_shader) or { panic('fragment shader') }
	context.shader_source(mut vertex, '#version 300 es\nuniform vec4 u_color; uniform mat3x2 u_matrix; void main() { gl_Position = u_color + vec4(u_matrix[0], 0.0, 0.0); }')
	context.shader_source(mut fragment, '#version 300 es\nprecision mediump float; out vec4 result; void main() { result = vec4(1.0); }')
	context.compile_shader(mut vertex)
	context.compile_shader(mut fragment)
	mut program := WebGLProgram.create(mut context)
	context.attach_shader(mut program, vertex)
	context.attach_shader(mut program, fragment)
	context.link_program(mut program)
	context.use_program(program)
	location := context.get_uniform_location(mut program, 'u_color') or { panic('uniform') }
	context.uniform4fv(location, [f32(1), 0.5, 0.25, 1])
	mut actual_color := [f32(0), 0, 0, 0]!
	C.vox_gl_get_uniform_floats(program.object.native_handle_, int(location.handle_), &actual_color[0])
	assert actual_color == [f32(1), 0.5, 0.25, 1]!
	assert context.get_uniform(program, location).integer == 0
	matrix := context.get_uniform_location(mut program, 'u_matrix') or { panic('matrix uniform') }
	context.uniform_matrix3x2fv(matrix, false, [f32(1), 0, 0, 1, 2, 3])
	mut actual_matrix := [f32(0), 0, 0, 0, 0, 0]!
	C.vox_gl_get_uniform_floats(program.object.native_handle_, int(matrix.handle_), &actual_matrix[0])
	assert actual_matrix == [f32(1), 0, 0, 1, 2, 3]!
	assert context.get_error() == no_error
	wrong_type_matrix := [f32(1), 0, 0, 1]!
	C.vox_gl_uniform_matrix(int(location.handle_), 2, 2, 1, 1, &wrong_type_matrix[0])
	expected_matrix_error := C.vox_gl_get_error()
	context.uniform_matrix2fv(location, true, wrong_type_matrix[..])
	actual_matrix_error := context.get_error()
	assert actual_matrix_error == expected_matrix_error

	mut buffer := WebGLBuffer.create(mut context)
	context.bind_buffer(uniform_buffer, buffer)
	context.buffer_data(uniform_buffer, []u8{len: 16}, 0x88e4)
	context.bind_buffer_range(uniform_buffer, 0, buffer, 0, 16)
	assert context.get_error() == no_error
	context.bind_buffer_range(uniform_buffer, 0, buffer, -1, 16)
	assert context.get_error() == invalid_value
}

fn test_upstream_spans_pixels_and_object_lifetime_factories() {
	mut context := WebGLRenderingContext.create(.webgl1, WebGLContextAttributes{}, [])
	mut bytes := [u8(1), 2, 3, 4]
	span := context.get_offset_span(bytes, 1, 2)!
	assert span == [u8(2), 3]
	bytes[1] = 9
	assert span == [u8(9), 3]
	assert context.span_from_float32_list([f32(1), 2, 3], 1, 0)! == [f32(2), 3]
	assert context.null_terminated_string([u8(`o`), `k`, 0, `x`]) == 'ok'
	assert WebGLQuery.create(mut context).object.handle_ != 0
	assert WebGLSampler.create(mut context).object.handle_ != 0
	assert WebGLTransformFeedback.create(mut context).object.handle_ != 0
	assert WebGLVertexArrayObject.create(mut context).object.handle_ != 0
	assert WebGLVertexArrayObjectOES.create(mut context).object.handle_ != 0
}

fn test_native_dispatch_transcript_is_opt_in() {
	mut context := WebGLRenderingContext.create(.webgl1, WebGLContextAttributes{}, [])
	context.clear(0x4000)
	assert context.native.native_calls().len == 0
	context.native.set_native_call_recording(true)
	context.clear(0x4000)
	assert context.native.native_calls().map(it.name) == ['clear']
	context.native.set_native_call_recording(false)
	assert context.native.native_calls().len == 0
}

fn test_upstream_parameter_queries_preserve_distinct_gl_state() {
	mut context := WebGLRenderingContext.create(.webgl2, WebGLContextAttributes{}, [])
	mut buffer := WebGLBuffer.create(mut context)
	context.bind_buffer(array_buffer, buffer)
	context.buffer_data(array_buffer, []u8{len: 32}, 0x88e8)
	assert context.get_buffer_parameter(array_buffer, buffer_size).integer == 32
	assert context.get_buffer_parameter(array_buffer, buffer_usage).integer == 0x88e8

	context.vertex_attrib_pointer(3, 2, unsigned_byte, true, 16, 8)
	queried_buffer := context.get_vertex_attrib(3, vertex_attrib_array_buffer_binding).buffer or { panic('source buffer wrapper') }
	assert queried_buffer.object.native_handle_ == buffer.object.native_handle_
	assert voidptr(queried_buffer) != voidptr(buffer)
	assert context.get_vertex_attrib(3, vertex_attrib_array_size).integer == 2
	assert context.get_vertex_attrib(3, vertex_attrib_array_normalized).boolean
	assert context.get_vertex_attrib(3, vertex_attrib_array_stride).integer == 16
	assert context.get_vertex_attrib_offset(3, vertex_attrib_array_pointer) == 8
	context.vertex_attrib2f(3, 4, 5)
	assert context.get_vertex_attrib(3, current_vertex_attrib).numbers == [f64(4), 5, 0, 1]

	mut vertex := WebGLShader.create(mut context, vertex_shader) or { panic('shader') }
	assert context.get_shader_parameter(vertex, shader_type).integer == vertex_shader
	assert !context.get_shader_parameter(vertex, compile_status).boolean
	mut program := WebGLProgram.create(mut context)
	context.attach_shader(mut program, vertex)
	assert context.get_program_parameter(program, attached_shaders).integer == 1
	assert !context.get_program_parameter(program, link_status).boolean
}
