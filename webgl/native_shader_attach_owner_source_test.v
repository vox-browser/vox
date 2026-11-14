// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl


fn shader_attach_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == expected
}

fn test_source_shader_attach_handle_and_slot_gates_precede_native_owner_and_retain_actual_refs() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		mut program := owner.create_program()
		mut foreign_program := other.create_program()
		foreign := other.create_shader(vertex_shader) or { panic('foreign shader') }
		vertex := owner.create_shader(vertex_shader) or { panic('vertex shader') }
		fragment := owner.create_shader(fragment_shader) or { panic('fragment shader') }
		same_vertex := owner.create_shader(vertex_shader) or { panic('other vertex shader') }
		same_fragment := owner.create_shader(fragment_shader) or { panic('other fragment shader') }
		deleted := owner.create_shader(vertex_shader) or { panic('deleted shader') }
		owner.delete_shader(deleted)
		for shader in [foreign, deleted] {
			other.native.make_current()
			owner.attach_shader(mut program, shader)
			shader_attach_owner([i32(9), 10, 11, 12]!)
			assert (owner.get_attached_shaders(program) or { panic('empty retained slots') }).len == 0
			assert owner.get_error() == invalid_operation
		}
		other.native.make_current()
		owner.attach_shader(mut foreign_program, vertex)
		shader_attach_owner([i32(9), 10, 11, 12]!)
		assert owner.get_error() == invalid_operation
		other.native.make_current()
		owner.attach_shader(mut program, fragment)
		shader_attach_owner([i32(1), 2, 3, 4]!)
		other.native.make_current()
		owner.attach_shader(mut program, vertex)
		shader_attach_owner([i32(1), 2, 3, 4]!)
		mut count := 0
		mut native_names := [u32(0), 0]!
		C.vox_gl_attached_shaders(program.object.native_name(), 2, &count, &native_names[0])
		assert count == 2
		assert vertex.object.native_name() in native_names
		assert fragment.object.native_name() in native_names
		assert owner.get_attached_shaders(program) or { panic('ordered retained refs') } == [
			vertex,
			fragment,
		]
		for shader in [vertex, fragment, same_vertex, same_fragment] {
			other.native.make_current()
			mut unused := i32(0)
			C.vox_gl_int_parameter(GLenum(0xffff_ffff), &unused)
			owner.attach_shader(mut program, shader)
			shader_attach_owner([i32(9), 10, 11, 12]!)
			assert owner.get_attached_shaders(program) or { panic('unchanged retained refs') } == [
				vertex,
				fragment,
			]
			assert C.vox_gl_get_error() == invalid_enum
			assert C.vox_gl_get_error() == no_error
			assert owner.get_error() == invalid_operation
		}
		owner.delete_program(program)
		other.native.make_current()
		owner.attach_shader(mut program, same_vertex)
		shader_attach_owner([i32(9), 10, 11, 12]!)
		assert owner.get_error() == invalid_operation
	}
}

fn test_source_duplicate_pointer_gate_precedes_type_gate_for_real_source_setter_record() {
	mut owner := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	owner.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	mut program := owner.create_program()
	fragment := owner.create_shader(fragment_shader) or { panic('retained fragment') }
	// Program.h's public setter accepts an actual shader pointer without a type gate.
	program.attached_vertex_shader = fragment
	other.native.make_current()
	owner.attach_shader(mut program, fragment)
	shader_attach_owner([i32(9), 10, 11, 12]!)
	assert program.attached_fragment_shader == none
	assert owner.get_attached_shaders(program) or { panic('source setter pointer') } == [fragment]
	assert owner.get_error() == invalid_operation
	owner.native.make_current()
	assert C.vox_gl_program_parameter(program.object.native_name(), attached_shaders) == 0
	assert owner.get_error() == no_error
}

fn test_source_shader_attach_retains_pointer_after_actual_owned_driver_rejection() {
	mut owner := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	owner.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	mut program := owner.create_program()
	shader := owner.create_shader(vertex_shader) or { panic('rejected native attach shader') }
	C.vox_gl_delete_program(program.object.native_name())
	C.vox_gl_attach_shader(program.object.native_name(), shader.object.native_name())
	expected := C.vox_gl_get_error()
	assert expected != no_error
	other.native.make_current()
	owner.attach_shader(mut program, shader)
	shader_attach_owner([i32(1), 2, 3, 4]!)
	assert owner.get_attached_shaders(program) or { panic('actual retained rejected shader') } == [shader]
	assert owner.get_error() == expected
}
