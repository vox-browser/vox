// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn source_vector_program(mut context WebGLRenderingContext) (&WebGLProgram, &WebGLUniformLocation) {
	prefix := if context.version == .webgl2 { '#version 300 es\n' } else { '' }
	mut vertex := context.create_shader(vertex_shader) or { panic('vertex') }
	mut fragment := context.create_shader(fragment_shader) or { panic('fragment') }
	context.shader_source(mut vertex, '${prefix}void main(){gl_Position=vec4(0,0,0,1);}')
	body := if context.version == .webgl2 {
		'out vec4 color;void main(){color=tint;}'
	} else {
		'void main(){gl_FragColor=tint;}'
	}
	context.shader_source(mut fragment, '${prefix}precision mediump float;uniform vec4 tint;${body}')
	context.compile_shader(mut vertex)
	context.compile_shader(mut fragment)
	mut program := context.create_program()
	context.attach_shader(mut program, vertex)
	context.attach_shader(mut program, fragment)
	context.link_program(mut program)
	assert context.get_program_parameter(program, link_status).boolean
	location := context.get_uniform_location(mut program, 'tint') or { panic('tint') }
	return program, location
}

fn source_vector_call(mut context WebGLRenderingContext, index int, location ?&WebGLUniformLocation, length int) {
	floats := []f32{len: length}
	ints := []int{len: length}
	uints := []u32{len: length}
	match index {
		0 { context.uniform1fv(location, floats) }
		1 { context.uniform2fv(location, floats) }
		2 { context.uniform3fv(location, floats) }
		3 { context.uniform4fv(location, floats) }
		4 { context.uniform1iv(location, ints) }
		5 { context.uniform2iv(location, ints) }
		6 { context.uniform3iv(location, ints) }
		7 { context.uniform4iv(location, ints) }
		8 { context.uniform1uiv(location, uints) }
		9 { context.uniform2uiv(location, uints) }
		10 { context.uniform3uiv(location, uints) }
		11 { context.uniform4uiv(location, uints) }
		else { panic('vector operation') }
	}
}

fn source_vector_owner_and_error(mut context WebGLRenderingContext, expected GLenum) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == [i32(1), 2, 3, 4]!
	actual_error := context.get_error()
	assert actual_error == expected
}

fn test_source_vector_uniform_bodies_select_owner_before_null_parent_and_size_returns() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		program, location := source_vector_program(mut context)
		_, foreign := source_vector_program(mut other)
		context.use_program(program)
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		operation_count := if version == .webgl2 { 12 } else { 8 }
		for index in 0 .. operation_count {
			width := index % 4 + 1
			other.native.make_current()
			source_vector_call(mut context, index, none, width + 1)
			source_vector_owner_and_error(mut context, no_error)
			other.native.make_current()
			source_vector_call(mut context, index, foreign, width + 1)
			source_vector_owner_and_error(mut context, invalid_operation)
			if width > 1 {
				other.native.make_current()
				source_vector_call(mut context, index, location, width + 1)
				source_vector_owner_and_error(mut context, invalid_value)
			}
		}
		// The host-facing location prelude also precedes offset/witness errors.
		other.native.make_current()
		accepted := context.validate_uniform_upload_location(none)
		assert !accepted
		source_vector_owner_and_error(mut context, no_error)
		other.native.make_current()
		foreign_accepted := context.validate_uniform_upload_location(foreign)
		assert !foreign_accepted
		source_vector_owner_and_error(mut context, invalid_operation)
	}
}
