// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn base_error_value_source_viewport() [4]i32 {
	mut value := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &value[0])
	return value
}

fn test_source_base_error_value_queries_owning_driver_after_early_source_branches() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		context.set_error(invalid_operation)
		context.native.set_pending_local_error(out_of_memory)
		assert context.get_error_value() == out_of_memory
		assert base_error_value_source_viewport() == [i32(9), 10, 11, 12]!
		context.native.make_current()
		C.vox_gl_enable(0xbad)
		other.native.make_current()
		C.vox_gl_viewport(0, 0, -1, 1)
		// GetError is a sync proxy call: the host selects this owning driver.
		assert context.get_error_value() == invalid_enum
		assert base_error_value_source_viewport() == [i32(1), 2, 3, 4]!
		assert context.get_error_value() == invalid_operation
		assert context.get_error_value() == no_error
		other.native.make_current()
		assert C.vox_gl_get_error() == invalid_value
		assert C.vox_gl_get_error() == no_error
		// Impl's Proxy::make_current is empty. A local return precedes sync selection.
		context.native.set_pending_local_error(out_of_memory)
		assert context.get_error() == out_of_memory
		assert base_error_value_source_viewport() == [i32(9), 10, 11, 12]!
		context.native.make_current()
		C.vox_gl_enable(0xbad)
		other.native.make_current()
		assert context.get_error() == invalid_enum
		assert base_error_value_source_viewport() == [i32(1), 2, 3, 4]!
		assert context.get_error_value() == no_error
		context.native.set_pending_local_error(out_of_memory)
		context.lose_context('source loss branch')
		other.native.make_current()
		assert context.get_error_value() == context_lost_webgl
		assert context.get_error_value() == no_error
		assert base_error_value_source_viewport() == [i32(9), 10, 11, 12]!
		assert context.native.take_pending_local_error() == out_of_memory
		assert context.get_error() == no_error
		assert base_error_value_source_viewport() == [i32(9), 10, 11, 12]!
		assert other.get_error() == no_error
	}
}

fn test_native_sync_error_query_selects_actual_owner_without_consuming_other_driver() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		C.vox_gl_enable(0xbad)
		other.viewport(9, 10, 11, 12)
		C.vox_gl_viewport(0, 0, -1, 1)
		assert context.native.get_error() == invalid_enum
		assert base_error_value_source_viewport() == [i32(1), 2, 3, 4]!
		assert other.native.get_error() == invalid_value
		assert base_error_value_source_viewport() == [i32(9), 10, 11, 12]!
		assert context.native.get_error() == no_error
		assert other.native.get_error() == no_error
	}
}
