// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_current_program_query_returns_actual_retained_record_after_driver_rejection() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		program := context.create_program()
		C.vox_gl_use_program(program.object.native_handle_)
		expected := C.vox_gl_get_error()
		assert expected != no_error
		context.use_program(program)
		result := context.get_parameter(current_program)
		assert result.kind == .object
		assert result.program? == program
		assert result.object == program.object.bookkeeping_id()
		mut actual := i32(-1)
		C.vox_gl_int_parameter(current_program, &actual)
		assert actual == 0
		assert context.get_error() == expected
		context.delete_program(program)
		assert context.get_parameter(current_program).program == none
		assert context.get_parameter(current_program).kind == .none
		assert context.get_error() == no_error
	}
}
