module streams

import math

fn test_queue_with_sizes_preserves_fifo_and_repairs_rounding() {
	mut queue := QueueWithSizes{}
	queue.enqueue_value_with_size(string_value('first'), 0.1)!
	queue.enqueue_value_with_size(string_value('second'), 0.2)!
	assert queue.len() == 2
	assert queue.peek_queue_value()!.text == 'first'
	assert queue.dequeue_value()!.text == 'first'
	assert queue.dequeue_value()!.text == 'second'
	assert queue.total_size() < 1e-12
	assert queue.is_empty()
}

fn test_queue_with_sizes_retains_source_linked_fifo_shape_for_long_queues() {
	mut queue := QueueWithSizes{}
	for index in 0 .. 4096 {
		queue.enqueue_value_with_size(number_value(index), 1)!
	}
	assert queue.queue_.values().len == 4096
	for index in 0 .. 4096 {
		assert queue.dequeue_value()!.number == index
	}
	assert queue.is_empty()
	assert queue.total_size() == 0
}

fn test_write_request_list_retains_source_linked_fifo_shape() {
	mut requests := VoidPromiseList{}
	mut promises := []&VoidPromise{cap: 4096}
	for _ in 0 .. 4096 {
		promise := VoidPromise.pending()
		promises << promise
		requests.append(promise)
	}
	assert requests.values().len == 4096
	for promise in promises {
		assert requests.shift()! == promise
	}
	assert requests.len == 0
}

fn test_queue_rejects_invalid_sizes_and_reset_clears_it() {
	mut queue := QueueWithSizes{}
	if _ := queue.enqueue_value_with_size(undefined_value(), -1) {
		assert false
	} else {
		assert err.msg().contains('non-negative')
	}
	if _ := queue.enqueue_value_with_size(undefined_value(), math.nan()) {
		assert false
	}
	if _ := queue.enqueue_value_with_size(undefined_value(), math.inf(1)) {
		assert false
	} else {
		assert err.msg().contains('finite')
	}
	queue.enqueue_value_with_size(number_value(4), 2)!
	queue.reset()
	assert queue.len() == 0
	assert queue.total_size() == 0
}

fn test_high_water_mark_and_size_algorithm_extraction() {
	assert extract_high_water_mark(QueuingStrategy{}, 7)! == 7
	assert extract_high_water_mark(QueuingStrategy{
		high_water_mark: 2.5
	}, 7)! == 2.5
	if _ := extract_high_water_mark(QueuingStrategy{
		high_water_mark: -0.1
	}, 1) {
		assert false
	} else {
		assert err.msg().contains('highWaterMark')
	}
	algorithm := extract_size_algorithm(QueuingStrategy{})
	assert algorithm(string_value('x'))! == 1
}

fn test_count_and_byte_length_queuing_strategies() {
	count := CountQueuingStrategy.create_for_constructor(QueuingStrategyInit{
		high_water_mark: 4
	})
	assert count.high_water_mark() == 4
	assert count.size(bytes_value([u8(1), 2, 3])) == 1
	byte_length := ByteLengthQueuingStrategy.create_for_constructor(QueuingStrategyInit{
		high_water_mark: 16
	})
	assert byte_length.high_water_mark() == 16
	assert byte_length.size(bytes_value([u8(1), 2, 3])) == 3
	assert byte_length.size(string_value('not an ArrayBufferView')) == 0
	assert CountQueuingStrategy.create(9).high_water_mark() == 9
	assert ByteLengthQueuingStrategy.create(12).high_water_mark() == 12
}

fn queuing_strategy_test_size(value Value) !f64 {
	if value.kind != .bytes {
		return error('expected bytes')
	}
	return f64(value.bytes_.len * 2)
}

fn test_queuing_strategy_size_callback_preserves_completion() {
	assert invoke_queuing_strategy_size_callback(queuing_strategy_test_size,
		bytes_value([u8(1), 2, 3]))! == 6
	if _ := invoke_queuing_strategy_size_callback(queuing_strategy_test_size, string_value('bad')) {
		assert false
	} else {
		assert err.msg() == 'expected bytes'
	}
}

fn test_array_buffer_transfer_clone_and_bounds() {
	mut source := ArrayBuffer.from_bytes([u8(10), 20, 30, 40])
	target := ArrayBuffer.from_bytes([u8(0), 0, 0, 0])
	assert can_transfer_array_buffer(&source)
	assert clone_as_uint8_array(&source, 1, 2)! == [u8(20), 30]
	assert !can_copy_data_block_bytes_buffer(&source, 0, &source, 1, 3)
	assert can_copy_data_block_bytes_buffer(&target, 0, &source, 1, 3)
	assert !can_copy_data_block_bytes_buffer(&target, 2, &source, 0, 3)
	transferred := transfer_array_buffer(mut source)!
	assert source.detached()
	assert source.byte_length() == 0
	assert transferred.bytes() == [u8(10), 20, 30, 40]
	if _ := clone_as_uint8_array(&source, 0, 0) {
		assert false
	} else {
		assert err.msg().contains('detached')
	}
}

fn test_structured_clone_and_message_packing_do_not_alias_bytes() {
	mut bytes := [u8(1), 2]
	value := bytes_value(bytes)
	mut port := MessagePort.create()
	pack_and_post_message(mut port, 'chunk', value)!
	bytes[0] = 9
	messages := port.messages()
	assert messages.len == 1
	assert messages[0].type_ == 'chunk'
	assert messages[0].value.bytes_ == [u8(1), 2]
	port.close()
	if _ := pack_and_post_message(mut port, 'chunk', value) {
		assert false
	} else {
		assert err.msg().contains('closed')
	}
}
