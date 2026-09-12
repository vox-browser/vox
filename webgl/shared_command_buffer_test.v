module webgl

fn test_shared_command_buffer_header_and_data_region() {
	mut command_buffer := WebGLSharedCommandBuffer.create(64)!
	assert command_buffer.is_valid()
	assert command_buffer.buffer().len == webgl_shared_data_region_offset + 64
	assert command_buffer.data_region().len == 64
	assert command_buffer.executed_flush_sequence_number() == 0

	command_buffer.store_executed_flush_sequence_number(0x0102030405060708)
	assert command_buffer.executed_flush_sequence_number() == 0x0102030405060708
	assert command_buffer.buffer()[..8] == [u8(8), 7, 6, 5, 4, 3, 2, 1]
}

fn test_adopted_shared_command_buffer_observes_same_storage() {
	mut producer := WebGLSharedCommandBuffer.create(32)!
	mut consumer := WebGLSharedCommandBuffer.adopt_received_buffer(producer.buffer()) or {
		panic('shared buffer was not adopted')
	}
	producer.store_executed_flush_sequence_number(7)
	assert consumer.executed_flush_sequence_number() == 7

	mut producer_data := producer.data_region()
	producer_data[0] = 42
	assert consumer.data_region()[0] == 42
	consumer.store_executed_flush_sequence_number(9)
	assert producer.executed_flush_sequence_number() == 9
}

fn test_shared_command_buffer_rejects_invalid_sizes_and_buffers() {
	invalid := WebGLSharedCommandBuffer{}
	assert !invalid.is_valid()
	assert invalid.executed_flush_sequence_number() == 0
	assert invalid.data_region().len == 0
	assert WebGLSharedCommandBuffer.adopt_received_buffer([]u8{len: webgl_shared_data_region_offset}) == none
	WebGLSharedCommandBuffer.create(-1) or {
		assert err.msg().contains('Invalid')
	}
}
