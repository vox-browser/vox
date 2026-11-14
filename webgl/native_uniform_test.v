module webgl

fn test_uniform_uploads_preserve_float_integer_unsigned_and_matrix_types() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut vertex := context.create_shader(vertex_shader) or { panic('shader') }
	mut fragment := context.create_shader(fragment_shader) or { panic('shader') }
	context.shader_source(mut vertex, '#version 300 es\nuniform vec4 colors[2]; uniform ivec2 integers; uniform uvec2 unsigned_values; uniform mat3x2 matrix; void main() { gl_Position = colors[0] + colors[1] + vec4(vec2(integers), vec2(unsigned_values)) + vec4(matrix[0], matrix[1]); }')
	context.shader_source(mut fragment, '#version 300 es\nprecision mediump float; out vec4 result; void main() { result = vec4(1.0); }')
	context.compile_shader(mut vertex)
	context.compile_shader(mut fragment)
	mut program := context.create_program()
	context.attach_shader(mut program, vertex)
	context.attach_shader(mut program, fragment)
	context.link_program(mut program)
	assert context.get_program_parameter(program, link_status).boolean
	context.use_program(program)
	colors := context.get_uniform_location(mut program, 'colors') or { panic('colors') }
	second_color := context.get_uniform_location(mut program, 'colors[1]') or { panic('array element') }
	float_data := [f32(0.125), 0.25, 0.5, 1, 0.375, 0.625, 0.875, 1]
	context.uniform4fv(colors, float_data)
	mut read_float := []f32{len: 4}
	C.vox_gl_get_uniform_floats(program.object.native_handle_, int(second_color.handle_), read_float.data)
	assert read_float == float_data[4..]
	integers := context.get_uniform_location(mut program, 'integers') or { panic('integers') }
	context.uniform2iv(integers, [int(-2_000_000_001), 2_000_000_001])
	mut read_int := []i32{len: 2}
	C.vox_gl_get_uniform_ints(program.object.native_handle_, int(integers.handle_), read_int.data)
	assert read_int == [i32(-2_000_000_001), 2_000_000_001]
	unsigned_values := context.get_uniform_location(mut program, 'unsigned_values') or { panic('unsigned') }
	context.uniform2ui(unsigned_values, 0xfedcba98, 0xffffffff)
	mut read_uint := []u32{len: 2}
	C.vox_gl_get_uniform_uints(program.object.native_handle_, int(unsigned_values.handle_), read_uint.data)
	assert read_uint == [u32(0xfedcba98), 0xffffffff]
	matrix := context.get_uniform_location(mut program, 'matrix') or { panic('matrix') }
	matrix_data := [f32(0.125), 0.25, 0.5, 1, 1.25, 1.5]
	context.uniform_matrix3x2fv(matrix, false, matrix_data)
	mut read_matrix := []f32{len: 6}
	C.vox_gl_get_uniform_floats(program.object.native_handle_, int(matrix.handle_), read_matrix.data)
	assert read_matrix == matrix_data
	assert context.get_error() == no_error
	context.uniform4iv(colors, [1, 2, 3, 4])
	assert context.get_error() == invalid_operation
	zero_matrix := []f32{len: 6}
	C.vox_gl_uniform_matrix(int(matrix.handle_), 3, 2, 1, 0, zero_matrix.data)
	C.vox_gl_uniform_matrix(int(matrix.handle_), 3, 2, 1, 1, matrix_data.data)
	expected_transpose_error := C.vox_gl_get_error()
	mut expected_matrix := []f32{len: 6}
	C.vox_gl_get_uniform_floats(program.object.native_handle_, int(matrix.handle_), expected_matrix.data)
	C.vox_gl_uniform_matrix(int(matrix.handle_), 3, 2, 1, 0, zero_matrix.data)
	context.uniform_matrix3x2fv(matrix, true, matrix_data)
	actual_transpose_error := context.get_error()
	C.vox_gl_get_uniform_floats(program.object.native_handle_, int(matrix.handle_), read_matrix.data)
	assert actual_transpose_error == expected_transpose_error
	assert read_matrix == expected_matrix
	context.uniform4fv(colors, [f32(1), 2, 3])
	assert context.get_error() == invalid_value
	context.uniform4fv(none, [f32(1), 2, 3])
	context.uniform_matrix3x2fv(none, true, [f32(1)])
	assert context.get_error() == no_error
}
