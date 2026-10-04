module webgl

fn test_query_lifecycle_and_error_queue() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut query := context.create_query()
	context.begin_query(any_samples_passed, mut query)
	assert context.get_query(any_samples_passed, current_query)? == query
	context.begin_query(any_samples_passed, mut query)
	assert context.get_error() == invalid_operation
	context.end_query(any_samples_passed)
	context.finish()
	assert context.get_query_parameter(query, query_result_available)? == 1
	context.end_query(any_samples_passed)
	assert context.get_error() == invalid_operation
}

fn test_webgl2_copy_sync_transform_feedback_and_offsets() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut source := context.create_buffer()
	mut destination := context.create_buffer()
	context.bind_buffer(copy_read_buffer, source)
	context.buffer_data(copy_read_buffer, [u8(1), 2, 3, 4], 0x88e4)
	context.bind_buffer(copy_write_buffer, destination)
	context.buffer_data(copy_write_buffer, [u8(0), 0, 0, 0], 0x88e4)
	context.copy_buffer_sub_data(copy_read_buffer, copy_write_buffer, 1, 0, 3)
	mut copied := []u8{len: 4}
	context.get_buffer_sub_data(copy_write_buffer, 0, mut copied, 0, 0)
	assert copied == [u8(2), 3, 4, 0]
	assert offset_span([u8(1), 2, 3], 1, 0)! == [u8(2), 3]
	mut sync := context.fence_sync(sync_gpu_commands_complete, 0) or { panic('sync') }
	assert context.client_wait_sync(mut sync, 0, 0) in [timeout_expired, already_signaled,
		condition_satisfied]
	// The generated compositor uses timeout 0 even for a nonzero requested wait.
	assert context.client_wait_sync(mut sync, sync_flush_commands_bit, 1_000_000_000) in [
		timeout_expired,
		condition_satisfied,
		already_signaled,
	]
	context.finish()
	assert context.client_wait_sync(mut sync, 0, 0) == already_signaled
	mut feedback := context.create_transform_feedback()
	context.bind_transform_feedback(transform_feedback, feedback)
	context.begin_transform_feedback(0x0004)
	assert context.get_error() == invalid_operation
	context.pause_transform_feedback()
	assert context.get_error() == invalid_operation
	context.resume_transform_feedback()
	assert context.get_error() == invalid_operation
	context.end_transform_feedback()
	assert context.get_error() == invalid_operation
}

fn test_surface_lifecycle_and_draw_validation() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.set_size(640, 480)
	assert context.drawing_buffer_width() == 640
	assert !context.needs_to_present()
	context.draw_arrays(0x0004, 0, 3)
	assert context.get_error() == invalid_operation
	assert context.needs_to_present()
	assert context.present()
	assert !context.needs_to_present()
	context.viewport(0, 0, -1, 2)
	assert context.get_error() == invalid_value
	context.set_size(0, -4)
	assert context.drawing_buffer_width() == 1
	assert context.drawing_buffer_height() == 1
}

fn test_oes_vertex_array_delete_invalidates_and_unbinds() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	context.get_extension('OES_vertex_array_object', false) or { panic('native VAO') }
	mut array := context.create_vertex_array_oes()
	context.bind_vertex_array_oes(array)
	assert context.is_vertex_array_oes(array)
	context.delete_vertex_array_oes(array)
	assert !context.is_vertex_array_oes(array)
	assert array.object.invalidated()
}
