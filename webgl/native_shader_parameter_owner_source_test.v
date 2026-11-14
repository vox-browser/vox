// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn shader_parameter_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == expected
}

fn test_source_shader_parameter_validates_handle_before_sync_and_queries_before_pname_switch() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		shader := owner.create_shader(vertex_shader) or { panic('owned parameter shader') }
		foreign := other.create_shader(vertex_shader) or { panic('foreign parameter shader') }
		for pname in [shader_type, compile_status, GLenum(0xbad)] {
			other.native.make_current()
			assert owner.get_shader_parameter(foreign, pname).kind == .none
			shader_parameter_owner([i32(9), 10, 11, 12]!)
			assert owner.get_error() == invalid_operation
		}
		other.native.make_current()
		assert owner.get_shader_parameter(shader, shader_type).integer == int(vertex_shader)
		shader_parameter_owner([i32(1), 2, 3, 4]!)
		other.native.make_current()
		assert !owner.get_shader_parameter(shader, compile_status).boolean
		shader_parameter_owner([i32(1), 2, 3, 4]!)
		assert owner.get_error() == no_error
		owner.native.make_current()
		C.vox_gl_shader_parameter(shader.object.native_name(), 0xbad)
		expected_native := C.vox_gl_get_error()
		assert expected_native != no_error
		other.native.make_current()
		assert owner.get_shader_parameter(shader, GLenum(0xbad)).kind == .none
		shader_parameter_owner([i32(1), 2, 3, 4]!)
		assert owner.get_error() == expected_native
		assert owner.get_error() == invalid_enum
		assert owner.get_error() == no_error
		// This valid native pname is outside Source's supported return switch.
		other.native.make_current()
		assert owner.get_shader_parameter(shader, GLenum(0x8b84)).kind == .none
		shader_parameter_owner([i32(1), 2, 3, 4]!)
		assert C.vox_gl_get_error() == no_error
		assert owner.get_error() == invalid_enum
		owner.delete_shader(shader)
		other.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		assert owner.get_shader_parameter(shader, GLenum(0xbad)).kind == .none
		shader_parameter_owner([i32(9), 10, 11, 12]!)
		assert C.vox_gl_get_error() == invalid_value
		assert owner.get_error() == invalid_operation
	}
}
