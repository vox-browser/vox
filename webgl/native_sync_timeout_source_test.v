// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_client_wait_host_timeout_override_preserves_actual_driver_states_and_errors() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	mut sync := context.fence_sync(sync_gpu_commands_complete, 0) or { panic('source actual fence') }
	for flags in [GLenum(0), sync_flush_commands_bit, GLenum(2), GLenum(0xffff_ffff)] {
		for requested_timeout in [u64(0), u64(1), u64(1_000_000_000), u64(-1)] {
			context.native.make_current()
			expected := C.vox_gl_client_wait_sync(sync.native_pointer(), flags, 0)
			expected_error := C.vox_gl_get_error()
			other.native.make_current()
			actual := context.client_wait_sync(mut sync, flags, requested_timeout)
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			if expected == wait_failed {
				assert actual == expected
			} else {
				// The real GPU can finish between the independent driver observations.
				assert actual in [timeout_expired, condition_satisfied, already_signaled]
			}
			assert context.get_error() == expected_error
		}
	}
	context.finish()
	assert context.client_wait_sync(mut sync, 0, u64(-1)) == already_signaled
	assert context.get_sync_parameter(sync, sync_status).integer == signaled
	context.delete_sync(mut sync)
	assert context.get_error() == no_error
}
