// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn program_link_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == expected
}

fn test_source_program_link_handle_gates_precede_native_owner_and_keep_actual_driver_results() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		mut program := owner.create_program()
		mut foreign := other.create_program()
		other.native.make_current()
		mut unused := i32(0)
		C.vox_gl_int_parameter(GLenum(0xffff_ffff), &unused)
		owner.link_program(mut foreign)
		program_link_owner([i32(9), 10, 11, 12]!)
		assert C.vox_gl_program_parameter(foreign.object.native_name(), link_status) == 0
		assert C.vox_gl_get_error() == invalid_enum
		assert C.vox_gl_get_error() == no_error
		assert owner.get_error() == invalid_operation
		mut vertex := owner.create_shader(vertex_shader) or { panic('link vertex') }
		mut fragment := owner.create_shader(fragment_shader) or { panic('link fragment') }
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
		other.native.make_current()
		owner.link_program(mut program)
		program_link_owner([i32(1), 2, 3, 4]!)
		assert C.vox_gl_program_parameter(program.object.native_name(), link_status) == 1
		assert owner.get_error() == no_error
		owner.delete_program(program)
		other.native.make_current()
		C.vox_gl_int_parameter(GLenum(0xffff_ffff), &unused)
		owner.link_program(mut program)
		program_link_owner([i32(9), 10, 11, 12]!)
		assert C.vox_gl_get_error() == invalid_enum
		assert C.vox_gl_get_error() == no_error
		assert owner.get_error() == invalid_operation
		mut rejected := owner.create_program()
		C.vox_gl_delete_program(rejected.object.native_name())
		C.vox_gl_link_program(rejected.object.native_name())
		expected := C.vox_gl_get_error()
		assert expected != no_error
		other.native.make_current()
		owner.link_program(mut rejected)
		program_link_owner([i32(1), 2, 3, 4]!)
		assert owner.get_error() == expected
	}
}
