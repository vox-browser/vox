module webgl

fn test_object_context_identity_buffer_compatibility_and_deletion() {
	mut first := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut second := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut buffer := first.create_buffer()
	assert buffer.object.handle(first.identity(), first.context_generation())! > 0
	buffer.object.handle(second.identity(), second.context_generation()) or {
		assert err.msg() == 'GL_INVALID_OPERATION'
	}
	assert buffer.is_compatible_with(array_buffer)
	assert buffer.is_compatible_with(copy_read_buffer)
	assert !buffer.is_compatible_with(element_array_buffer)
	first.bind_buffer(array_buffer, buffer)
	first.buffer_data(array_buffer, [u8(1), 2, 3, 4], 0x88e4)
	first.buffer_sub_data(array_buffer, 1, [u8(9), 8])
	mut uploaded := []u8{len: 4}
	first.get_buffer_sub_data(array_buffer, 0, mut uploaded, 0, 0)
	assert uploaded == [u8(1), 9, 8, 4]
	first.delete_buffer(buffer)
	assert !first.is_buffer(buffer)
	assert buffer.object.invalidated()
}

fn test_buffer_element_array_class_is_sticky() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut buffer := context.create_buffer()
	context.bind_buffer(element_array_buffer, buffer)
	assert context.get_error() == no_error
	context.bind_buffer(array_buffer, buffer)
	assert context.get_error() == invalid_operation
}

fn test_object_generation_invalidates_pre_loss_wrappers() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut old_buffer := context.create_buffer()
	old_handle := old_buffer.object.handle_
	assert old_buffer.object.handle_for_query(context.identity(), context.context_generation())!.has_value

	context.reset_context_state_after_loss()
	assert context.context_generation() == 1
	assert old_buffer.object.invalidated_for_context(context.context_generation())
	old_buffer.object.handle(context.identity(), context.context_generation()) or {
		assert err.msg() == 'GL_INVALID_OPERATION'
	}
	assert !old_buffer.object.handle_for_query(context.identity(), context.context_generation())!.has_value
	assert !context.is_buffer(old_buffer)

	context.native.set_native_call_recording(true)
	context.delete_buffer(old_buffer)
	assert context.get_error() == no_error
	assert context.native.native_calls().filter(it.name == 'delete_buffer').len == 0

	new_buffer := context.create_buffer()
	assert new_buffer.object.context_generation == 1
	assert new_buffer.object.handle_ != old_handle
	assert !context.is_buffer(new_buffer)
	context.bind_buffer(array_buffer, new_buffer)
	assert context.is_buffer(new_buffer)
}

fn test_object_deletion_is_idempotent_but_foreign_context_is_an_error() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut foreign_context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut buffer := context.create_buffer()
	context.native.set_native_call_recording(true)
	context.delete_buffer(buffer)
	context.delete_buffer(buffer)
	assert context.get_error() == no_error
	assert context.native.native_calls().filter(it.name == 'delete_buffer').len == 1

	foreign_context.delete_buffer(buffer)
	assert foreign_context.get_error() == invalid_operation
	assert !foreign_context.is_buffer(context.create_buffer())
	assert foreign_context.get_error() == invalid_operation
}

fn test_sync_deletion_uses_generation_aware_sync_handle() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut sync := context.fence_sync(sync_gpu_commands_complete, 0) or { panic('missing sync') }
	assert sync.sync_handle(context.identity(), context.context_generation())! == sync.source_handle_
	assert uint(sync.source_handle_) == 1
	assert sync.native_handle_ != unsafe { nil }
	context.reset_context_state_after_loss()
	sync.sync_handle(context.identity(), context.context_generation()) or {
		assert err.msg() == 'GL_INVALID_OPERATION'
	}
	context.delete_sync(mut sync)
	assert context.get_error() == no_error
}
