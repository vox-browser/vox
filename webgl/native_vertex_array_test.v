module webgl

fn native_vao_float_bytes(values []f32) []u8 {
	return unsafe { (&u8(values.data)).vbytes(values.len * 4).clone() }
}

fn native_vao_program(mut context WebGLRenderingContext) {
	mut vertex := context.create_shader(vertex_shader) or { panic('vertex') }
	mut fragment := context.create_shader(fragment_shader) or { panic('fragment') }
	context.shader_source(mut vertex, '#version 300 es\nin vec2 position; void main() { gl_Position=vec4(position,0.0,1.0); }')
	context.shader_source(mut fragment, '#version 300 es\nprecision mediump float; out vec4 color; void main() { color=vec4(1.0,0.0,0.0,1.0); }')
	context.compile_shader(mut vertex)
	context.compile_shader(mut fragment)
	mut program := context.create_program()
	context.attach_shader(mut program, vertex)
	context.attach_shader(mut program, fragment)
	context.bind_attrib_location(program, 0, 'position')
	context.link_program(mut program)
	assert context.get_program_parameter(program, link_status).boolean
	context.use_program(program)
}

fn test_native_vertex_arrays_retain_attribute_and_element_buffer_state() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.set_size(4, 4)
	native_vao_program(mut context)
	mut triangle := context.create_vertex_array()
	empty := context.create_vertex_array()
	assert triangle.object.native_handle_ != 0
	assert !context.is_vertex_array(triangle)
	context.bind_vertex_array(triangle)
	assert context.is_vertex_array(triangle)
	vertices := context.create_buffer()
	indices := context.create_buffer()
	context.bind_buffer(array_buffer, vertices)
	context.buffer_data(array_buffer, native_vao_float_bytes([f32(99), -1, -1, 3, -1, -1, 3]), 0x88e4)
	context.vertex_attrib_pointer(0, 2, gl_float, false, 0, 4)
	context.enable_vertex_attrib_array(0)
	context.bind_buffer(element_array_buffer, indices)
	context.buffer_data(element_array_buffer, [u8(0), 1, 2], 0x88e4)
	context.bind_vertex_array(empty)
	assert !context.get_vertex_attrib(0, vertex_attrib_array_enabled).boolean
	assert context.get_vertex_attrib(0, vertex_attrib_array_size).integer == 4
    assert context.get_vertex_attrib(0, vertex_attrib_array_type).integer == int(gl_float)
	empty_buffer := context.get_vertex_attrib(0, vertex_attrib_array_buffer_binding).buffer or { panic('source empty buffer wrapper') }
	assert empty_buffer.object.native_handle_ == 0
	assert context.get_parameter(element_array_buffer_binding).object == indices.object.handle_
	assert context.get_vertex_attrib_offset(0, vertex_attrib_array_pointer) == 0
	context.bind_vertex_array(triangle)
	assert context.get_vertex_attrib(0, vertex_attrib_array_enabled).boolean
	assert context.get_vertex_attrib(0, vertex_attrib_array_size).integer == 2
	queried_vertices := context.get_vertex_attrib(0, vertex_attrib_array_buffer_binding).buffer or { panic('source vertex buffer wrapper') }
	assert queried_vertices.object.native_handle_ == vertices.object.native_handle_
	assert context.get_parameter(element_array_buffer_binding).object == indices.object.handle_
	assert context.get_vertex_attrib_offset(0, vertex_attrib_array_pointer) == 4
	context.draw_elements(0x0004, 3, unsigned_byte, 0)
	pixels := context.read_pixels(0, 0, 4, 4, rgba, unsigned_byte)
	for offset := 0; offset < pixels.len; offset += 4 {
		assert pixels[offset..offset + 4] == [u8(255), 0, 0, 255]
	}
	assert context.get_error() == no_error
	context.delete_vertex_array(triangle)
	assert !context.is_vertex_array(triangle)
	assert context.get_parameter(vertex_array_binding).kind == .none
	assert context.get_parameter(element_array_buffer_binding).object == indices.object.handle_
	context.get_vertex_attrib(0xffffffff, vertex_attrib_array_size)
	assert context.get_error() == invalid_value
}

fn test_native_oes_vertex_arrays_use_actual_requested_extension() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	context.get_extension('OES_vertex_array_object', false) or { panic('VAO extension') }
	mut array := context.create_vertex_array_oes()
	assert array.object.native_handle_ != 0
	assert !context.is_vertex_array_oes(array)
	context.bind_vertex_array_oes(array)
	assert context.is_vertex_array_oes(array)
	context.enable_vertex_attrib_array(1)
	context.bind_vertex_array_oes(none)
	assert !context.get_vertex_attrib(1, vertex_attrib_array_enabled).boolean
	context.bind_vertex_array_oes(array)
	assert context.get_vertex_attrib(1, vertex_attrib_array_enabled).boolean
	context.delete_vertex_array_oes(array)
	assert !context.get_vertex_attrib(1, vertex_attrib_array_enabled).boolean
	assert context.get_error() == no_error
}
