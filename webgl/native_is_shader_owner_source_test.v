// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn is_shader_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == expected
}

fn test_source_is_shader_optional_handle_gates_precede_actual_driver_owner() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		owner.native.make_current()
		mut reserved := []GLuint{}
		for _ in 0 .. 8 { reserved << C.vox_gl_create_shader(vertex_shader) }
		shader := owner.create_shader(vertex_shader) or { panic('actual is-shader record') }
		assert shader.object.native_name() !in reserved
		assert shader.object.handle(owner.identity(), owner.context_generation())! == 1
		C.vox_gl_delete_shader(reserved[0])
		assert C.vox_gl_is_object(9, reserved[0]) == 0
		mut program := owner.create_program()
		owner.attach_shader(mut program, shader)
		foreign := other.create_shader(vertex_shader) or { panic('foreign is-shader record') }
		other.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		assert !owner.is_shader(none)
		is_shader_owner([i32(9), 10, 11, 12]!)
		assert C.vox_gl_get_error() == invalid_value
		assert owner.get_error() == no_error
		other.native.make_current()
		assert !owner.is_shader(foreign)
		is_shader_owner([i32(9), 10, 11, 12]!)
		assert owner.get_error() == invalid_operation
		other.native.make_current()
		assert owner.is_shader(shader)
		is_shader_owner([i32(1), 2, 3, 4]!)
		assert owner.get_error() == no_error
		owner.delete_shader(shader)
		assert C.vox_gl_is_object(9, shader.object.native_name()) == 1
		other.native.make_current()
		assert !owner.is_shader(shader)
		is_shader_owner([i32(9), 10, 11, 12]!)
		assert owner.get_error() == no_error
		other.delete_shader(foreign)
		other.native.make_current()
		assert !owner.is_shader(foreign)
		is_shader_owner([i32(9), 10, 11, 12]!)
		assert owner.get_error() == invalid_operation
		owner.native.make_current()
		for name in reserved[1..] { C.vox_gl_delete_shader(name) }
		assert owner.get_error() == no_error
	}
}
