// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_sync_creation_retains_owned_records_after_actual_driver_rejection() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	conditions := [GLenum(0), sync_gpu_commands_complete, 0]
	flags := [GLenum(0), 1, 1]
	for index, condition in conditions {
		context.native.make_current()
		expected_handle := C.vox_gl_fence_sync(condition, flags[index])
		expected_error := C.vox_gl_get_error()
		assert expected_handle == unsafe { nil }
		assert expected_error != no_error
		other.native.make_current()
		mut sync := context.fence_sync(condition, flags[index]) or { panic('source null-handle sync record') }
		assert sync.native_handle_ == expected_handle
		assert context.owns(&sync.object)
		assert !sync.object.invalidated()
		assert context.syncs[sync.object.handle_] == sync
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		actual_error := context.get_error()
		assert actual_error == expected_error
		// Source ownership permits the null driver handle to reach GL queries.
		expected_value := C.vox_gl_get_sync_parameter(expected_handle, sync_condition)
		expected_query_error := C.vox_gl_get_error()
		actual_value := context.get_sync_parameter(sync, sync_condition)
		actual_query_error := context.get_error()
		assert actual_value.kind == .integer
		assert actual_value.integer == expected_value
		assert actual_query_error == expected_query_error
		C.vox_gl_delete_sync(expected_handle)
		expected_delete_error := C.vox_gl_get_error()
		context.delete_sync(sync)
		actual_delete_error := context.get_error()
		assert actual_delete_error == expected_delete_error
		assert sync.object.invalidated()
		assert !context.owns(&sync.object)
	}
}
