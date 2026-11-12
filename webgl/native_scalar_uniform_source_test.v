// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn scalar_uniform_source_program(mut context WebGLRenderingContext, index int) (&WebGLProgram, &WebGLUniformLocation) {
	types := ['float', 'vec2', 'vec3', 'vec4', 'int', 'ivec2', 'ivec3', 'ivec4', 'uint', 'uvec2',
		'uvec3', 'uvec4']
	expressions := ['vec4(value)', 'vec4(value,0.0,1.0)', 'vec4(value,1.0)', 'value',
		'vec4(float(value))', 'vec4(vec2(value),0.0,1.0)', 'vec4(vec3(value),1.0)', 'vec4(value)',
		'vec4(float(value))', 'vec4(vec2(value),0.0,1.0)', 'vec4(vec3(value),1.0)', 'vec4(value)']
	prefix := if context.version == .webgl2 { '#version 300 es\n' } else { '' }
	mut vertex := context.create_shader(vertex_shader) or { panic('vertex') }
	mut fragment := context.create_shader(fragment_shader) or { panic('fragment') }
	context.shader_source(mut vertex, '${prefix}void main(){gl_Position=vec4(0,0,0,1);}')
	output := if context.version == .webgl2 { 'out vec4 color;' } else { '' }
	output_name := if context.version == .webgl2 { 'color' } else { 'gl_FragColor' }
	context.shader_source(mut fragment, '${prefix}precision mediump float;uniform ${types[index]} value;${output}void main(){${output_name}=${expressions[index]};}')
	context.compile_shader(mut vertex)
	context.compile_shader(mut fragment)
	mut program := context.create_program()
	context.attach_shader(mut program, vertex)
	context.attach_shader(mut program, fragment)
	context.link_program(mut program)
	assert context.get_program_parameter(program, link_status).boolean
	location := context.get_uniform_location(mut program, 'value') or { panic('value') }
	assert location.handle_ == 0
	return program, location
}

fn scalar_uniform_source_driver(index int, zero bool) {
	floats := if zero { [f32(0), 0, 0, 0]! } else { [f32(0.25), 0.5, 0.75, 1]! }
	ints := if zero { [i32(0), 0, 0, 0]! } else { [i32(1), 2, 3, 4]! }
	uints := if zero {
		[u32(0), 0, 0, 0]!
	} else {
		[u32(0xffffffff), 0x80000000, 0x10000001, 0x7fffffff]!
	}
	match index {
		0 { C.vox_gl_uniform1f(0, floats[0]) }
		1 { C.vox_gl_uniform2f(0, floats[0], floats[1]) }
		2 { C.vox_gl_uniform3f(0, floats[0], floats[1], floats[2]) }
		3 { C.vox_gl_uniform4f(0, floats[0], floats[1], floats[2], floats[3]) }
		4 { C.vox_gl_uniform1i(0, ints[0]) }
		5 { C.vox_gl_uniform2i(0, ints[0], ints[1]) }
		6 { C.vox_gl_uniform3i(0, ints[0], ints[1], ints[2]) }
		7 { C.vox_gl_uniform4i(0, ints[0], ints[1], ints[2], ints[3]) }
		8 { C.vox_gl_uniform1ui(0, uints[0]) }
		9 { C.vox_gl_uniform2ui(0, uints[0], uints[1]) }
		10 { C.vox_gl_uniform3ui(0, uints[0], uints[1], uints[2]) }
		11 { C.vox_gl_uniform4ui(0, uints[0], uints[1], uints[2], uints[3]) }
		else { panic('scalar operation') }
	}
}

fn scalar_uniform_source_call(mut context WebGLRenderingContext, index int, location ?&WebGLUniformLocation, zero bool) {
	floats := if zero { [f32(0), 0, 0, 0]! } else { [f32(0.25), 0.5, 0.75, 1]! }
	ints := if zero { [i32(0), 0, 0, 0]! } else { [i32(1), 2, 3, 4]! }
	uints := if zero {
		[u32(0), 0, 0, 0]!
	} else {
		[u32(0xffffffff), 0x80000000, 0x10000001, 0x7fffffff]!
	}
	match index {
		0 { context.uniform1f(location, floats[0]) }
		1 { context.uniform2f(location, floats[0], floats[1]) }
		2 { context.uniform3f(location, floats[0], floats[1], floats[2]) }
		3 { context.uniform4f(location, floats[0], floats[1], floats[2], floats[3]) }
		4 { context.uniform1i(location, ints[0]) }
		5 { context.uniform2i(location, ints[0], ints[1]) }
		6 { context.uniform3i(location, ints[0], ints[1], ints[2]) }
		7 { context.uniform4i(location, ints[0], ints[1], ints[2], ints[3]) }
		8 { context.uniform1ui(location, uints[0]) }
		9 { context.uniform2ui(location, uints[0], uints[1]) }
		10 { context.uniform3ui(location, uints[0], uints[1], uints[2]) }
		11 { context.uniform4ui(location, uints[0], uints[1], uints[2], uints[3]) }
		else { panic('scalar operation') }
	}
}

fn scalar_uniform_source_query(program &WebGLProgram, width int) []f32 {
	mut values := [f32(0), 0, 0, 0]!
	C.vox_gl_get_uniform_floats(program.object.native_handle_, 0, &values[0])
	return values[..width].clone()
}

fn scalar_uniform_source_owner() {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == [i32(1), 2, 3, 4]!
}

fn test_source_scalar_uniforms_use_owner_nullable_zero_and_exact_driver_operations() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		operation_count := if version == .webgl2 { 12 } else { 8 }
		for index in 0 .. operation_count {
			program, location := scalar_uniform_source_program(mut context, index)
			_, foreign_location := scalar_uniform_source_program(mut other, index)
			context.use_program(program)
			width := index % 4 + 1
			scalar_uniform_source_driver(index, false)
			expected_error := C.vox_gl_get_error()
			expected_values := scalar_uniform_source_query(program, width)
			assert expected_error == no_error
			scalar_uniform_source_driver(index, true)
			assert scalar_uniform_source_query(program, width) == []f32{len: width}
			other.native.make_current()
			scalar_uniform_source_call(mut context, index, none, false)
			scalar_uniform_source_owner()
			actual_error := context.get_error()
			assert actual_error == expected_error
			assert scalar_uniform_source_query(program, width) == expected_values
			if index >= 8 {
				mut actual_uints := [u32(0), 0, 0, 0]!
				C.vox_gl_get_uniform_uints(program.object.native_handle_, 0, &actual_uints[0])
				expected_uints := [u32(0xffffffff), 0x80000000, 0x10000001, 0x7fffffff]!
				assert actual_uints[..width] == expected_uints[..width]
			}
			// A present record still uses its native location after pointer validation.
			other.native.make_current()
			scalar_uniform_source_call(mut context, index, location, true)
			scalar_uniform_source_owner()
			assert scalar_uniform_source_query(program, width) == []f32{len: width}
			other.native.make_current()
			scalar_uniform_source_call(mut context, index, foreign_location, false)
			scalar_uniform_source_owner()
			foreign_error := context.get_error()
			assert foreign_error == invalid_operation
			assert scalar_uniform_source_query(program, width) == []f32{len: width}
			context.use_program(none)
			scalar_uniform_source_driver(index, false)
			expected_unbound_error := C.vox_gl_get_error()
			other.native.make_current()
			scalar_uniform_source_call(mut context, index, none, false)
			scalar_uniform_source_owner()
			actual_unbound_error := context.get_error()
			assert actual_unbound_error == expected_unbound_error
			assert actual_unbound_error == invalid_operation
		}
	}
}
