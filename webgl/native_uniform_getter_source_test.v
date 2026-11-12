// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn source_get_uniform_program(mut context WebGLRenderingContext) (&WebGLProgram, &WebGLUniformLocation) {
	mut vertex := context.create_shader(vertex_shader) or { panic('vertex') }
	mut fragment := context.create_shader(fragment_shader) or { panic('fragment') }
	prefix := if context.version == .webgl2 { '#version 300 es\n' } else { '' }
	context.shader_source(mut vertex, '${prefix}void main(){gl_Position=vec4(0,0,0,1);}')
	fragment_body := if context.version == .webgl2 {
		'out vec4 color;void main(){color=tint;}'
	} else {
		'void main(){gl_FragColor=tint;}'
	}
	context.shader_source(mut fragment, '${prefix}precision mediump float;uniform vec4 tint;${fragment_body}')
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

fn test_source_get_uniform_returns_exact_zero_without_owner_handle_or_driver_queries() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		program, location := source_get_uniform_program(mut context)
		foreign_program, foreign_location := source_get_uniform_program(mut other)
		context.use_program(program)
		context.uniform4f(location, 1, 0.5, 0.25, 1)
		mut actual_uniform := [f32(0), 0, 0, 0]!
		C.vox_gl_get_uniform_floats(program.object.native_handle_, int(location.handle_), &actual_uniform[0])
		assert actual_uniform == [f32(1), 0.5, 0.25, 1]!
		actual_upload_error := context.get_error()
		assert actual_upload_error == no_error
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		programs := [program, foreign_program, program]
		locations := [location, location, foreign_location]
		for index, argument_program in programs {
			value := context.get_uniform(argument_program, locations[index])
			assert value.kind == .integer && value.integer == 0
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
		}
		// An unrelated actual driver error must survive the source FIXME body.
		C.vox_gl_enable(0xbad)
		pending_value := context.get_uniform(program, location)
		pending_error := C.vox_gl_get_error()
		assert pending_value.kind == .integer && pending_value.integer == 0
		assert pending_error == invalid_enum
		context.delete_program(program)
		other.native.make_current()
		deleted_value := context.get_uniform(program, location)
		assert deleted_value.kind == .integer && deleted_value.integer == 0
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		actual_body_error := context.get_error()
		assert actual_body_error == no_error
	}
}
