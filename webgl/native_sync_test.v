module webgl

fn test_webgl_sync_wait_and_queries_use_actual_angle_gpu_results() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	assert !context.native.is_lost()
	mut sync := context.fence_sync(sync_gpu_commands_complete, 0) or { panic('native fence failed') }
	assert sync.native_handle_ != unsafe { nil }
	assert context.get_sync_parameter(sync, sync_condition).integer == sync_gpu_commands_complete
	assert context.get_sync_parameter(sync, sync_flags).integer == 0
	assert context.get_sync_parameter(sync, sync_status).integer in [i64(unsignaled), i64(signaled)]
	assert context.client_wait_sync(mut sync, 0, 0) in [timeout_expired, condition_satisfied,
		already_signaled]
	// The flush bit is valid; the Source compositor uses timeout 0 even when
	// the original wire request supplied a nonzero timeout.
	assert context.client_wait_sync(mut sync, sync_flush_commands_bit, 1_000_000_000) in [
		timeout_expired,
		condition_satisfied,
		already_signaled,
	]
	context.finish()
	assert context.get_sync_parameter(sync, sync_status).integer == signaled
	assert context.client_wait_sync(mut sync, 0, 0) == already_signaled
	context.wait_sync(mut sync, 0, u64(-1))
	assert context.get_error() == no_error
	context.delete_sync(sync)
	assert sync.object.invalidated()
	context.delete_sync(sync)
	assert context.get_error() == no_error
}

fn test_webgl_sync_errors_come_from_native_gl_and_context_ownership() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	invalid_flags := context.fence_sync(sync_gpu_commands_complete, 1) or { panic('source sync record') }
	assert invalid_flags.native_handle_ == unsafe { nil }
	assert context.owns(&invalid_flags.object)
	assert context.get_error() == invalid_value
	invalid_condition := context.fence_sync(0, 0) or { panic('source sync record') }
	assert invalid_condition.native_handle_ == unsafe { nil }
	assert context.owns(&invalid_condition.object)
	assert context.get_error() == invalid_enum
	mut sync := context.fence_sync(sync_gpu_commands_complete, 0) or { panic('native fence failed') }
	assert context.client_wait_sync(mut sync, 2, 0) == wait_failed
	assert context.get_error() == invalid_value
	context.wait_sync(mut sync, sync_flush_commands_bit, u64(-1))
	assert context.get_error() == invalid_value
	context.wait_sync(mut sync, 0, 0)
	assert context.get_error() == invalid_value
	context.get_sync_parameter(sync, GLenum(0))
	assert context.get_error() == invalid_enum
	mut foreign := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	assert foreign.client_wait_sync(mut sync, 0, 0) == wait_failed
	assert foreign.get_error() == invalid_operation
	context.delete_sync(sync)
	assert context.client_wait_sync(mut sync, 0, 0) == wait_failed
	assert context.get_error() == invalid_operation
}
