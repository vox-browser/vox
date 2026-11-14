// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn program_delete_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == expected
}

fn test_source_program_deletion_cpu_gates_and_actual_deferred_current_program_lifetime() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		mut program := owner.create_program()
		mut vertex := owner.create_shader(vertex_shader) or { panic('program deletion vertex') }
		mut fragment := owner.create_shader(fragment_shader) or { panic('program deletion fragment') }
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
		native_name := program.object.native_name()
		source_id := program.object.handle(owner.identity(), owner.context_generation())!
		foreign := other.create_program()
		other.native.make_current()
		mut unused := i32(0)
		C.vox_gl_int_parameter(GLenum(0xffff_ffff), &unused)
		owner.delete_program(none)
		program_delete_owner([i32(9), 10, 11, 12]!)
		owner.delete_program(foreign)
		program_delete_owner([i32(9), 10, 11, 12]!)
		assert !foreign.object.invalidated()
		assert C.vox_gl_is_object(10, foreign.object.native_name()) == 1
		assert C.vox_gl_get_error() == invalid_enum
		assert C.vox_gl_get_error() == no_error
		assert owner.get_error() == invalid_operation
		other.native.make_current()
		owner.delete_program(program)
		program_delete_owner([i32(1), 2, 3, 4]!)
		assert program.object.invalidated()
		assert program.object.source_handle_ == source_id
		assert program.object.native_name() == native_name
		assert C.vox_gl_is_object(10, native_name) == 1
		assert C.vox_gl_program_parameter(native_name, delete_status) == 1
		mut actual := i32(0)
		C.vox_gl_int_parameter(current_program, &actual)
		assert actual == int(native_name)
		assert owner.get_parameter(current_program).program == none
		assert owner.get_error() == no_error
		other.native.make_current()
		owner.delete_program(program)
		program_delete_owner([i32(9), 10, 11, 12]!)
		assert owner.get_error() == no_error
		other.native.make_current()
		other.delete_program(program)
		program_delete_owner([i32(9), 10, 11, 12]!)
		assert other.get_error() == invalid_operation
		owner.native.make_current()
		C.vox_gl_use_program(0)
		assert C.vox_gl_is_object(10, native_name) == 0
		assert owner.get_error() == no_error
	}
}

fn test_source_program_deletion_invalidates_before_actual_driver_rejection() {
	mut owner := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	owner.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	program := owner.create_program()
	name := program.object.native_name()
	C.vox_gl_delete_program(name)
	C.vox_gl_delete_program(name)
	expected := C.vox_gl_get_error()
	assert expected != no_error
	other.native.make_current()
	owner.delete_program(program)
	program_delete_owner([i32(1), 2, 3, 4]!)
	assert program.object.invalidated()
	assert program.object.native_name() == name
	assert owner.get_error() == expected
}
