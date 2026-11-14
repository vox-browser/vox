// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn program_use_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == expected
}

fn test_source_use_program_gates_precede_native_owner_but_null_dispatches_and_driver_rejection_retains_record() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		mut program := owner.create_program()
		mut vertex := owner.create_shader(vertex_shader) or { panic('use vertex') }
		mut fragment := owner.create_shader(fragment_shader) or { panic('use fragment') }
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
		owner.use_program(program)
		name := program.object.native_name()
		foreign := other.create_program()
		deleted := owner.create_program()
		owner.delete_program(deleted)
		for rejected in [foreign, deleted] {
			other.native.make_current()
			mut unused := i32(0)
			C.vox_gl_int_parameter(GLenum(0xffff_ffff), &unused)
			owner.use_program(rejected)
			program_use_owner([i32(9), 10, 11, 12]!)
			assert owner.current_program or { panic('unchanged retained program') } == program
			assert C.vox_gl_get_error() == invalid_enum
			assert C.vox_gl_get_error() == no_error
			assert owner.get_error() == invalid_operation
		}
		other.native.make_current()
		owner.use_program(none)
		program_use_owner([i32(1), 2, 3, 4]!)
		mut actual := i32(-1)
		C.vox_gl_int_parameter(current_program, &actual)
		assert actual == 0
		assert owner.current_program == none
		assert owner.get_error() == no_error
		other.native.make_current()
		owner.use_program(program)
		program_use_owner([i32(1), 2, 3, 4]!)
		C.vox_gl_int_parameter(current_program, &actual)
		assert actual == int(name)
		assert owner.current_program or { panic('owned retained program') } == program
		assert owner.get_error() == no_error
		rejected := owner.create_program()
		C.vox_gl_use_program(rejected.object.native_name())
		expected := C.vox_gl_get_error()
		assert expected != no_error
		other.native.make_current()
		owner.use_program(rejected)
		program_use_owner([i32(1), 2, 3, 4]!)
		C.vox_gl_int_parameter(current_program, &actual)
		assert actual == int(name)
		assert owner.current_program or { panic('source record after native rejection') } == rejected
		assert owner.get_error() == expected
		owner.use_program(none)
		assert owner.current_program == none
		assert owner.get_error() == no_error
	}
}
