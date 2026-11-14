// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn matrix_source_program(mut context WebGLRenderingContext, columns int, rows int) (&WebGLProgram, &WebGLUniformLocation) {
	prefix := if context.version == .webgl2 { '#version 300 es\n' } else { '' }
	type_ := if columns == rows { 'mat${columns}' } else { 'mat${columns}x${rows}' }
	padding := if rows == 2 {
		',0.0,0.0'
	} else if rows == 3 {
		',0.0'
	} else {
		''
	}
	mut terms := []string{}
	for column in 0 .. columns {
		terms << 'vec4(data[${column}]${padding})'
	}
	output := if context.version == .webgl2 { 'out vec4 color;' } else { '' }
	output_name := if context.version == .webgl2 { 'color' } else { 'gl_FragColor' }
	mut vertex := context.create_shader(vertex_shader) or { panic('vertex') }
	mut fragment := context.create_shader(fragment_shader) or { panic('fragment') }
	context.shader_source(mut vertex, '${prefix}void main(){gl_Position=vec4(0,0,0,1);}')
	context.shader_source(mut fragment, '${prefix}precision mediump float;uniform ${type_} data;${output}void main(){${output_name}=${terms.join('+')};}')
	context.compile_shader(mut vertex)
	context.compile_shader(mut fragment)
	mut program := context.create_program()
	context.attach_shader(mut program, vertex)
	context.attach_shader(mut program, fragment)
	context.link_program(mut program)
	assert context.get_program_parameter(program, link_status).boolean
	location := context.get_uniform_location(mut program, 'data') or { panic('matrix') }
	return program, location
}

fn matrix_source_call(mut context WebGLRenderingContext, index int, location ?&WebGLUniformLocation, transpose bool, values []f32) {
	match index {
		0 { context.uniform_matrix2fv(location, transpose, values) }
		1 { context.uniform_matrix3fv(location, transpose, values) }
		2 { context.uniform_matrix4fv(location, transpose, values) }
		3 { context.uniform_matrix3x2fv(location, transpose, values) }
		4 { context.uniform_matrix4x2fv(location, transpose, values) }
		5 { context.uniform_matrix2x3fv(location, transpose, values) }
		6 { context.uniform_matrix4x3fv(location, transpose, values) }
		7 { context.uniform_matrix2x4fv(location, transpose, values) }
		8 { context.uniform_matrix3x4fv(location, transpose, values) }
		else { panic('matrix operation') }
	}
}

fn matrix_source_query(program &WebGLProgram, location &WebGLUniformLocation, size int) []f32 {
	mut values := []f32{len: size}
	C.vox_gl_get_uniform_floats(program.object.native_handle_, int(location.handle_), values.data)
	return values
}

fn matrix_source_owner_and_error(mut context WebGLRenderingContext, expected GLenum) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == [i32(1), 2, 3, 4]!
	actual_error := context.get_error()
	assert actual_error == expected
}

fn test_source_matrix_uniforms_preserve_transpose_driver_errors_and_owner_order() {
	columns := [2, 3, 4, 3, 4, 2, 4, 2, 3]
	rows := [2, 3, 4, 2, 2, 3, 3, 4, 4]
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		operation_count := if version == .webgl2 { 9 } else { 3 }
		for index in 0 .. operation_count {
			program, location := matrix_source_program(mut context, columns[index], rows[index])
			_, foreign := matrix_source_program(mut other, columns[index], rows[index])
			context.use_program(program)
			size := columns[index] * rows[index]
			values := []f32{len: size, init: f32(index + 1)}
			zero := []f32{len: size}
			bad_size := []f32{len: size + 1}
			other.native.make_current()
			matrix_source_call(mut context, index, none, true, bad_size)
			matrix_source_owner_and_error(mut context, no_error)
			other.native.make_current()
			matrix_source_call(mut context, index, foreign, true, bad_size)
			matrix_source_owner_and_error(mut context, invalid_operation)
			other.native.make_current()
			matrix_source_call(mut context, index, location, true, bad_size)
			matrix_source_owner_and_error(mut context, invalid_value)
			matrix_source_call(mut context, index, location, false, values)
			matrix_source_owner_and_error(mut context, no_error)
			assert matrix_source_query(program, location, size) == values
			// Compare true against GL after resetting both oracle and V to zero.
			C.vox_gl_uniform_matrix(int(location.handle_), columns[index], rows[index], 1, 0, zero.data)
			C.vox_gl_uniform_matrix(int(location.handle_), columns[index], rows[index], 1, 1, values.data)
			expected_error := C.vox_gl_get_error()
			expected_values := matrix_source_query(program, location, size)
			C.vox_gl_uniform_matrix(int(location.handle_), columns[index], rows[index], 1, 0, zero.data)
			assert matrix_source_query(program, location, size) == zero
			other.native.make_current()
			matrix_source_call(mut context, index, location, true, values)
			matrix_source_owner_and_error(mut context, expected_error)
			assert matrix_source_query(program, location, size) == expected_values
			// Keep Source's program pointer while removing only the native binding.
			C.vox_gl_use_program(0)
			C.vox_gl_uniform_matrix(int(location.handle_), columns[index], rows[index], 1, 1, values.data)
			expected_unbound_error := C.vox_gl_get_error()
			other.native.make_current()
			matrix_source_call(mut context, index, location, true, values)
			matrix_source_owner_and_error(mut context, expected_unbound_error)
		}
	}
}
