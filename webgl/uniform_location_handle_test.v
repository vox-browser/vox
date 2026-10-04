// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn uniform_location_handle_mismatch(location &WebGLUniformLocation, current ?&WebGLProgram) {
	location.handle(current) or {
		assert err.msg() == 'GL_INVALID_OPERATION'
		return
	}
	assert false
}

fn test_source_uniform_location_handle_compares_optional_program_pointer_identity() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	program := context.create_program()
	other := context.create_program()
	parentless := WebGLUniformLocation.create(0, none)
	parentless_handle := parentless.handle(none) or { panic(err) }
	assert parentless_handle == 0
	uniform_location_handle_mismatch(parentless, program)
	location := WebGLUniformLocation.create(3, program)
	matching_handle := location.handle(program) or { panic(err) }
	assert matching_handle == 3
	uniform_location_handle_mismatch(location, none)
	uniform_location_handle_mismatch(location, other)
	// Source checks the retained pointer, without querying native link/deletion.
	context.delete_program(program)
	deleted_parent_handle := location.handle(program) or { panic(err) }
	assert deleted_parent_handle == 3
}
