// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn is_program_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == expected
}

fn test_source_is_program_optional_gates_precede_actual_owner_and_use_native_name() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		owner.native.make_current()
		mut reserved := []GLuint{}
		for _ in 0 .. 8 { reserved << C.vox_gl_create_program() }
		mut program := owner.create_program()
		assert program.object.native_name() !in reserved
		assert program.object.handle(owner.identity(), owner.context_generation())! == 1
		C.vox_gl_delete_program(reserved[0])
		assert C.vox_gl_is_object(10, reserved[0]) == 0
		mut vertex := owner.create_shader(vertex_shader) or { panic('program vertex shader') }
		mut fragment := owner.create_shader(fragment_shader) or { panic('program fragment shader') }
		owner.shader_source(mut vertex, if version == .webgl2 {
			'#version 300 es
void main(){gl_Position=vec4(0);}'
		} else {
			'void main(){gl_Position=vec4(0);}'
		})
		owner.shader_source(mut fragment, if version == .webgl2 {
			'#version 300 es
precision mediump float;out vec4 color;void main(){color=vec4(1);}'
		} else {
			'precision mediump float;void main(){gl_FragColor=vec4(1);}'
		})
		owner.compile_shader(mut vertex)
		owner.compile_shader(mut fragment)
		owner.attach_shader(mut program, vertex)
		owner.attach_shader(mut program, fragment)
		owner.link_program(mut program)
		assert owner.get_program_parameter(program, link_status).boolean
		foreign := other.create_program()
		other.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		assert !owner.is_program(none)
		is_program_owner([i32(9), 10, 11, 12]!)
		assert C.vox_gl_get_error() == invalid_value
		assert owner.get_error() == no_error
		other.native.make_current()
		assert !owner.is_program(foreign)
		is_program_owner([i32(9), 10, 11, 12]!)
		assert owner.get_error() == invalid_operation
		other.native.make_current()
		assert owner.is_program(program)
		is_program_owner([i32(1), 2, 3, 4]!)
		assert owner.get_error() == no_error
		owner.use_program(program)
		owner.delete_program(program)
		assert C.vox_gl_is_object(10, program.object.native_name()) == 1
		other.native.make_current()
		assert !owner.is_program(program)
		is_program_owner([i32(9), 10, 11, 12]!)
		assert owner.get_error() == no_error
		other.delete_program(foreign)
		other.native.make_current()
		assert !owner.is_program(foreign)
		is_program_owner([i32(9), 10, 11, 12]!)
		assert owner.get_error() == invalid_operation
		owner.native.make_current()
		C.vox_gl_use_program(0)
		assert C.vox_gl_is_object(10, program.object.native_name()) == 0
		owner.delete_shader(vertex)
		owner.delete_shader(fragment)
		for name in reserved[1..] { C.vox_gl_delete_program(name) }
		assert owner.get_error() == no_error
	}
}
