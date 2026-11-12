// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn program_diagnostic_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == expected
}

fn test_source_program_info_log_keeps_handle_gate_before_actual_regular_sync_query() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		program := owner.create_program()
		foreign := other.create_program()
		other.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		assert owner.get_program_info_log(foreign) == none
		program_diagnostic_owner([i32(9), 10, 11, 12]!)
		assert C.vox_gl_get_error() == invalid_value
		assert owner.get_error() == invalid_operation
		other.native.make_current()
		assert owner.get_program_info_log(program) or { panic('owned empty program log') } == ''
		program_diagnostic_owner([i32(1), 2, 3, 4]!)
		assert owner.get_error() == no_error
		// A failed link outside V supplies a genuine driver log.
		owner.native.make_current()
		C.vox_gl_link_program(program.object.native_name())
		assert C.vox_gl_program_parameter(program.object.native_name(), link_status) == 0
		length := C.vox_gl_program_parameter(program.object.native_name(), GLenum(0x8b84))
		assert length > 1
		mut bytes := []u8{len: length}
		C.vox_gl_program_log(program.object.native_name(), length, bytes.data)
		actual_log := bytes[..length - 1].bytestr()
		other.native.make_current()
		assert owner.get_program_info_log(program) or { panic('actual driver program log') } == actual_log
		program_diagnostic_owner([i32(1), 2, 3, 4]!)
		assert owner.get_error() == no_error
		owner.delete_program(program)
		other.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		assert owner.get_program_info_log(program) == none
		program_diagnostic_owner([i32(9), 10, 11, 12]!)
		assert C.vox_gl_get_error() == invalid_value
		assert owner.get_error() == invalid_operation
	}
}
