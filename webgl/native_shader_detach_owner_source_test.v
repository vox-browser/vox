// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn shader_detach_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == expected
}

fn test_source_detach_shader_handle_gates_precede_native_owner_and_clear_after_driver_rejection() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		mut program := owner.create_program()
		vertex := owner.create_shader(vertex_shader) or { panic('retained vertex') }
		fragment := owner.create_shader(fragment_shader) or { panic('retained fragment') }
		unattached := owner.create_shader(vertex_shader) or { panic('unattached vertex') }
		deleted := owner.create_shader(vertex_shader) or { panic('deleted vertex') }
		owner.delete_shader(deleted)
		owner.attach_shader(mut program, vertex)
		owner.attach_shader(mut program, fragment)
		mut foreign_program := other.create_program()
		foreign := other.create_shader(vertex_shader) or { panic('foreign vertex') }
		for shader in [foreign, deleted] {
			other.native.make_current()
			mut unused := i32(0)
			C.vox_gl_int_parameter(GLenum(0xffff_ffff), &unused)
			owner.detach_shader(mut program, shader)
			shader_detach_owner([i32(9), 10, 11, 12]!)
			assert owner.get_attached_shaders(program) or { panic('gate retains refs') } == [
				vertex,
				fragment,
			]
			assert C.vox_gl_get_error() == invalid_enum
			assert C.vox_gl_get_error() == no_error
			assert owner.get_error() == invalid_operation
		}
		other.native.make_current()
		owner.detach_shader(mut foreign_program, vertex)
		shader_detach_owner([i32(9), 10, 11, 12]!)
		assert foreign_program.attached_vertex_shader == none
		assert owner.get_error() == invalid_operation
		owner.native.make_current()
		C.vox_gl_detach_shader(program.object.native_name(), unattached.object.native_name())
		expected := C.vox_gl_get_error()
		assert expected != no_error
		assert C.vox_gl_program_parameter(program.object.native_name(), attached_shaders) == 2
		other.native.make_current()
		owner.detach_shader(mut program, unattached)
		shader_detach_owner([i32(1), 2, 3, 4]!)
		assert owner.get_attached_shaders(program) or { panic('rejected clears vertex slot') } == [fragment]
		assert C.vox_gl_program_parameter(program.object.native_name(), attached_shaders) == 2
		assert owner.get_error() == expected
		// A cleared Source slot adds no gate against detaching the actual GL attachment.
		other.native.make_current()
		owner.detach_shader(mut program, vertex)
		shader_detach_owner([i32(1), 2, 3, 4]!)
		assert C.vox_gl_program_parameter(program.object.native_name(), attached_shaders) == 1
		assert owner.get_attached_shaders(program) or { panic('fragment remains') } == [fragment]
		assert owner.get_error() == no_error
		other.native.make_current()
		owner.detach_shader(mut program, fragment)
		shader_detach_owner([i32(1), 2, 3, 4]!)
		assert C.vox_gl_program_parameter(program.object.native_name(), attached_shaders) == 0
		assert (owner.get_attached_shaders(program) or { panic('empty retained refs') }).len == 0
		assert owner.get_error() == no_error
		owner.delete_program(program)
		other.native.make_current()
		owner.detach_shader(mut program, vertex)
		shader_detach_owner([i32(9), 10, 11, 12]!)
		assert owner.get_error() == invalid_operation
	}
}
