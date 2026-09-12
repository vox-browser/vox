module webgl

fn test_context_proxy_publishes_and_rewinds_shared_ranges() {
	mut proxy := WebGLContextProxyBase.new(.webgl2, ['GL_EXT_test'], 64)!
	proxy.max_pending_command_bytes_ = 128
	proxy.record_bytes(1, [u8(1)], []u8{})!
	proxy.record_bytes(2, [u8(2)], []u8{})!
	assert proxy.shared_data_cursor_ == 32
	proxy.flush_commands()
	assert proxy.shared_data_flush_base_ == 32
	assert proxy.transmitted_batches().len == 1
	assert proxy.transmitted_batches()[0].uses_shared_buffer
	assert proxy.transmitted_batches()[0].flush_sequence_number == 1

	proxy.acknowledge_flush(1)
	proxy.rewind_shared_data_cursor_if_all_published_commands_executed()
	assert proxy.shared_data_cursor_ == 0
	assert proxy.shared_data_flush_base_ == 0
	assert WebGLCommandList.for_each_command(proxy.transmitted_batches()[0].bytes)!.map(it.type_) == [
		WebGLCommandType(1),
		2,
	]
}

fn test_context_proxy_waits_before_reusing_published_bytes() {
	mut proxy := WebGLContextProxyBase.new(.webgl1, []string{}, 32)!
	proxy.max_pending_command_bytes_ = 128
	proxy.record_bytes(1, [u8(1)], []u8{})!
	proxy.record_bytes(2, [u8(2)], []u8{})!
	proxy.record_bytes(3, [u8(3)], []u8{})!
	assert !proxy.is_lost()
	assert proxy.transmitted_batches().len == 1
	assert proxy.shared_command_buffer_.executed_flush_sequence_number() == 1
	assert proxy.shared_data_cursor_ == 16

	mut failing := WebGLContextProxyBase.new(.webgl1, []string{}, 32)!
	failing.max_pending_command_bytes_ = 128
	failing.wait_for_execution_succeeds_ = false
	failing.record_bytes(1, [u8(1)], []u8{})!
	failing.record_bytes(2, [u8(2)], []u8{})!
	failing.record_bytes(3, [u8(3)], []u8{})!
	assert failing.is_lost()
	assert failing.shared_data_cursor_ == failing.shared_data_flush_base_
}

fn test_context_proxy_uses_out_of_line_and_oversized_batches() {
	mut fallback := WebGLContextProxyBase.new(.webgl1, []string{}, 64)!
	fallback.disable_shared_command_buffer()
	fallback.max_pending_command_bytes_ = 16
	fallback.record_bytes(3, [u8(1)], []u8{})!
	assert fallback.transmitted_batches().len == 1
	assert !fallback.transmitted_batches()[0].uses_shared_buffer

	mut proxy := WebGLContextProxyBase.new(.webgl2, []string{}, 32)!
	proxy.record_bytes(4, []u8{len: 40}, []u8{})!
	assert proxy.transmitted_batches().len == 1
	assert !proxy.transmitted_batches()[0].uses_shared_buffer
	assert WebGLCommandList.for_each_command(proxy.transmitted_batches()[0].bytes)!.first().type_ == 4
}

fn test_context_proxy_sync_calls_errors_and_restore() {
	mut proxy := WebGLContextProxyBase.new(.webgl2, ['before'], 64)!
	assert proxy.allocate_object_id() == WebGLObjectId(1)
	assert proxy.allocate_object_id() == WebGLObjectId(2)
	proxy.set_pending_local_error(invalid_value)
	proxy.set_pending_local_error(invalid_enum)
	assert proxy.take_pending_local_error() == invalid_value
	assert proxy.take_pending_local_error() == no_error

	proxy.set_next_sync_reply([u8(7), 8])
	assert proxy.send_sync_call([u8(1)]) == [u8(7), 8]
	assert !proxy.is_lost()
	assert proxy.send_sync_call([u8(1)]).len == 0
	assert proxy.is_lost()
	assert proxy.canvas_id() == none

	proxy.restore(['after'], 32)!
	assert !proxy.is_lost()
	assert proxy.get_supported_opengl_extensions() == ['after']
	assert proxy.canvas_id() != none
}
