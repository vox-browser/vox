// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn program_parameter_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == expected
}

fn test_source_program_parameter_handle_gate_precedes_actual_eager_sync_query() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		program := owner.create_program()
		foreign := other.create_program()
		other.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		assert owner.get_program_parameter(foreign, link_status).kind == .none
		program_parameter_owner([i32(9), 10, 11, 12]!)
		assert C.vox_gl_get_error() == invalid_value
		assert owner.get_error() == invalid_operation
		other.native.make_current()
		result := owner.get_program_parameter(program, link_status)
		assert result.kind == .boolean
		assert !result.boolean
		program_parameter_owner([i32(1), 2, 3, 4]!)
		assert owner.get_error() == no_error
		// Source queries before its return switch even for unsupported pnames.
		other.native.make_current()
		assert owner.get_program_parameter(program, GLenum(0xbad)).kind == .none
		program_parameter_owner([i32(1), 2, 3, 4]!)
		assert owner.get_error() == invalid_enum
		assert owner.get_error() == invalid_enum
		assert owner.get_error() == no_error
		owner.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		other.native.make_current()
		// A valid native pname outside Source's switch retains only its fallback.
		assert owner.get_program_parameter(program, GLenum(0x8b84)).kind == .none
		program_parameter_owner([i32(1), 2, 3, 4]!)
		assert owner.get_error() == invalid_value
		assert owner.get_error() == invalid_enum
		assert owner.get_error() == no_error
		owner.native.make_current()
		C.vox_gl_delete_program(program.object.native_name())
		assert owner.owns(&program.object)
		other.native.make_current()
		rejected := owner.get_program_parameter(program, link_status)
		assert rejected.kind == .boolean
		assert !rejected.boolean
		program_parameter_owner([i32(1), 2, 3, 4]!)
		assert owner.get_error() == invalid_value
		assert owner.get_error() == no_error
		owner.delete_program(program)
		// Clear the separate deletion's native result before testing this CPU gate.
		C.vox_gl_get_error()
		other.native.make_current()
		assert owner.get_program_parameter(program, link_status).kind == .none
		program_parameter_owner([i32(9), 10, 11, 12]!)
		assert owner.get_error() == invalid_operation
		assert owner.get_error() == no_error
	}
}
