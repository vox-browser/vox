// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn base_error_value_source_viewport() [4]int {
	mut value := [0, 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &value[0])
	return value
}

fn test_source_base_error_value_drains_source_priorities_without_adding_owner_selection() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		context.set_error(invalid_value)
		context.native.set_pending_local_error(out_of_memory)
		assert context.get_error_value() == out_of_memory
		assert base_error_value_source_viewport() == [9, 10, 11, 12]!
		context.native.make_current()
		C.vox_gl_enable(0xbad)
		assert context.get_error_value() == invalid_enum
		assert context.get_error_value() == invalid_value
		assert context.get_error_value() == no_error
		// Impl::get_error selects the owner before delegating to the base body.
		C.vox_gl_enable(0xbad)
		other.native.make_current()
		assert context.get_error() == invalid_enum
		assert base_error_value_source_viewport() == [1, 2, 3, 4]!
		assert context.get_error_value() == no_error
		context.native.set_pending_local_error(out_of_memory)
		context.lose_context('source loss branch')
		other.native.make_current()
		assert context.get_error_value() == context_lost_webgl
		assert context.get_error_value() == no_error
		assert base_error_value_source_viewport() == [9, 10, 11, 12]!
		assert context.native.take_pending_local_error() == out_of_memory
		assert other.get_error() == no_error
	}
}
