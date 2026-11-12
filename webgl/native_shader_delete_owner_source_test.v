// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn shader_delete_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == expected
}

fn test_source_nullable_shader_deletion_validates_before_native_owner_and_retains_attached_record() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		shader := owner.create_shader(vertex_shader) or { panic('owned delete shader') }
		foreign := other.create_shader(vertex_shader) or { panic('foreign delete shader') }
		mut program := owner.create_program()
		owner.attach_shader(mut program, shader)
		other.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		owner.delete_shader(none)
		shader_delete_owner([i32(9), 10, 11, 12]!)
		assert C.vox_gl_get_error() == invalid_value
		assert owner.get_error() == no_error
		other.native.make_current()
		owner.delete_shader(foreign)
		shader_delete_owner([i32(9), 10, 11, 12]!)
		assert !foreign.object.invalidated()
		assert C.vox_gl_is_object(9, foreign.object.native_name()) == 1
		assert owner.get_error() == invalid_operation
		actual_name := shader.object.native_name()
		source_handle := shader.object.handle(owner.identity(), owner.context_generation())!
		other.native.make_current()
		owner.delete_shader(shader)
		shader_delete_owner([i32(1), 2, 3, 4]!)
		assert shader.object.invalidated()
		assert shader.object.source_handle_ == source_handle
		assert shader.object.native_name() == actual_name
		assert C.vox_gl_is_object(9, actual_name) == 1
		assert C.vox_gl_shader_parameter(actual_name, delete_status) == 1
		assert owner.get_error() == no_error
		other.native.make_current()
		assert owner.get_attached_shaders(program) or { panic('retained deleted attachment') } == [shader]
		shader_delete_owner([i32(9), 10, 11, 12]!)
		other.native.make_current()
		owner.delete_shader(shader)
		shader_delete_owner([i32(9), 10, 11, 12]!)
		assert owner.get_error() == no_error
		other.native.make_current()
		other.delete_shader(shader)
		shader_delete_owner([i32(9), 10, 11, 12]!)
		assert other.get_error() == invalid_operation
		owner.native.make_current()
		assert C.vox_gl_shader_parameter(actual_name, delete_status) == 1
	}
}

fn test_source_shader_deletion_invalidates_before_genuine_native_rejection() {
	mut owner := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	owner.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	shader := owner.create_shader(vertex_shader) or { panic('externally removed shader') }
	name := shader.object.native_name()
	C.vox_gl_delete_shader(name)
	C.vox_gl_delete_shader(name)
	expected := C.vox_gl_get_error()
	assert expected != no_error
	other.native.make_current()
	owner.delete_shader(shader)
	shader_delete_owner([i32(1), 2, 3, 4]!)
	assert shader.object.invalidated()
	assert shader.object.native_name() == name
	assert owner.get_error() == expected
}
