module streams

fn upstream_test_start() ! {}

fn upstream_test_pull() ! {}

fn upstream_test_cancel(_ Value) ! {}

fn upstream_test_failing_start() ! {
	return error('setup start failed')
}

fn upstream_test_write(_ Value) ! {}

fn upstream_test_close() ! {}

fn upstream_test_abort(_ Value) ! {}

fn upstream_test_size_two(_ Value) !f64 {
	return 2
}

fn test_readable_abstract_operations_share_controller_state() {
	mut stream := create_readable_stream(upstream_test_start, upstream_test_pull, upstream_test_cancel, 2.0, count_size_algorithm)!
	mut controller := stream.default_controller()!
	assert controller.strategy_hwm() == 2
	assert readable_stream_default_controller_can_close_or_enqueue(controller)
	readable_stream_default_controller_enqueue(mut controller, string_value('chunk'))!
	assert controller.queue_total_size() == 1
	assert readable_stream_default_controller_get_desired_size(controller)? == 1
	assert !readable_stream_default_controller_has_backpressure(controller)
	mut reader := acquire_readable_stream_default_reader(mut stream)!
	read := readable_stream_default_reader_read(mut reader)
	assert read.result().value.text == 'chunk'
	assert readable_stream_has_default_reader(stream)
	readable_stream_default_reader_release(mut reader)
	assert !is_readable_stream_locked(stream)
}

fn test_default_controller_backpressure_accounts_for_pending_read_requests() {
	mut stream := create_readable_stream(upstream_test_start, upstream_test_pull, upstream_test_cancel, 0.0, count_size_algorithm)!
	mut controller := stream.default_controller()!
	assert readable_stream_default_controller_has_backpressure(controller)
	mut reader := acquire_readable_stream_default_reader(mut stream)!
	pending := readable_stream_default_reader_read(mut reader)
	assert pending.state() == .pending
	assert !readable_stream_default_controller_has_backpressure(controller)
	readable_stream_default_controller_enqueue(mut controller, string_value('ready'))!
	assert pending.result().value.text == 'ready'
}

fn test_default_controller_close_and_error_clear_source_algorithms() {
	mut closing := create_readable_stream(upstream_test_start, upstream_test_pull, upstream_test_cancel, 1.0, count_size_algorithm)!
	mut closing_controller := closing.default_controller()!
	readable_stream_default_controller_close(mut closing_controller)
	assert closing.state() == .closed
	if _ := closing_controller.pull_algorithm() {
		assert false
	}
	if _ := closing_controller.cancel_algorithm() {
		assert false
	}
	closing_size := closing_controller.strategy_size_algorithm()
	assert closing_size(undefined_value())! == 1

	mut failing := create_readable_stream(upstream_test_start, upstream_test_pull, upstream_test_cancel, 1.0, upstream_test_size_two)!
	mut failing_controller := failing.default_controller()!
	readable_stream_default_controller_error(mut failing_controller, string_value('broken'))
	assert failing.state() == .errored
	if _ := failing_controller.pull_algorithm() {
		assert false
	}
	if _ := failing_controller.cancel_algorithm() {
		assert false
	}
	failing_size_algorithm := failing_controller.strategy_size_algorithm()
	assert failing_size_algorithm(undefined_value())! == 1
}

fn test_default_controller_close_clears_algorithms_after_queue_drain() {
	mut stream := create_readable_stream(upstream_test_start, upstream_test_pull, upstream_test_cancel, 1.0, upstream_test_size_two)!
	mut controller := stream.default_controller()!
	readable_stream_default_controller_enqueue(mut controller, string_value('last'))!
	readable_stream_default_controller_close(mut controller)
	assert stream.state() == .readable
	assert controller.close_requested()
	if _ := controller.pull_algorithm() {
		// Algorithms remain available until the final queued chunk is read.
	} else {
		assert false
	}
	mut reader := acquire_readable_stream_default_reader(mut stream)!
	read := readable_stream_default_reader_read(mut reader)
	assert read.result().value.text == 'last'
	assert stream.state() == .closed
	if _ := controller.pull_algorithm() {
		assert false
	}
	if _ := controller.cancel_algorithm() {
		assert false
	}
}

fn test_default_controller_internal_enqueue_returns_after_close_while_idl_enqueue_rejects() {
	mut stream := create_readable_stream(upstream_test_start, upstream_test_pull, upstream_test_cancel, 1.0, count_size_algorithm)!
	mut controller := stream.default_controller()!
	controller.close()!
	assert stream.state() == .closed

	readable_stream_default_controller_enqueue(mut controller, string_value('ignored'))!
	assert controller.queue().len == 0
	if _ := controller.enqueue(string_value('rejected')) {
		assert false
	} else {
		assert err.msg().contains('cannot enqueue')
	}

	controller.set_queue_total_size(-3)
	assert controller.queue_total_size() == -3
}

fn test_default_controller_setup_resets_controller_state() {
	mut stream := ReadableStream{
		started_: true
		close_requested_: true
		pull_again_: true
		pulling_: true
	}
	stream.queue_.enqueue_value_with_size(string_value('stale'), 4)!
	mut controller := ReadableStreamDefaultController{}
	set_up_readable_stream_default_controller(mut stream, mut controller, upstream_test_start, upstream_test_pull, upstream_test_cancel, 2.0, count_size_algorithm)!
	assert controller.started()
	assert !controller.close_requested()
	assert !controller.pull_again()
	assert !controller.pulling()
	assert controller.queue().len == 0
	assert controller.queue_total_size() == 0
}

fn test_default_controller_setup_propagates_start_exception_without_erroring_stream() {
	mut stream := ReadableStream{}
	mut controller := ReadableStreamDefaultController{}
	set_up_readable_stream_default_controller(mut stream, mut controller, upstream_test_failing_start, upstream_test_pull, upstream_test_cancel, 1.0, count_size_algorithm) or {
		assert err.msg() == 'setup start failed'
		assert stream.state() == .readable
		assert !controller.started()
		return
	}
	assert false
}

fn test_create_readable_stream_with_existing_stream_keeps_controller_on_destination() {
	mut stream := ReadableStream{}
	create_readable_stream_with_existing_stream(mut stream, UnderlyingSource{}, QueuingStrategy{})!
	mut controller := stream.default_controller()!
	controller.enqueue(string_value('destination'))!
	assert stream.queued_chunks() == 1
	assert controller.stream() == &stream
}

fn test_readable_stream_error_does_not_run_controller_error_steps() {
	mut stream := create_readable_stream(upstream_test_start, upstream_test_pull, upstream_test_cancel, 2.0, count_size_algorithm)!
	mut controller := stream.default_controller()!
	controller.enqueue(string_value('queued'))!
	readable_stream_error(mut stream, string_value('abstract error'))
	assert stream.state() == .errored
	assert stream.stored_error() == 'abstract error'
	assert controller.queue().len == 1
	if _ := controller.pull_algorithm() {
		assert true
	} else {
		assert false
	}
}

fn test_byte_controller_entry_points_fill_byob_request() {
	mut stream := create_readable_byte_stream(upstream_test_start, upstream_test_pull, upstream_test_cancel)!
	mut reader := acquire_readable_stream_byob_reader(mut stream)!
	pending := readable_stream_byob_reader_read(mut reader, 4, 2)
	assert pending.state() == .pending
	mut controller := stream.byte_controller()!
	mut request := readable_byte_stream_controller_get_byob_request(mut controller) or {
		panic('missing BYOB request')
	}
	request.write_view([u8(4), 5])!
	readable_byte_stream_controller_respond(mut controller, 2)!
	assert pending.result().value == [u8(4), 5]
	assert controller.raw_byob_request() == none
}

fn test_writable_entry_points_preserve_slots_and_sentinel() {
	mut stream := create_writable_stream(upstream_test_start, upstream_test_write, upstream_test_close, upstream_test_abort, 1, count_size_algorithm)!
	request := writable_stream_add_write_request(mut stream)
	assert stream.write_requests().len == 1
	writable_stream_mark_first_write_request_in_flight(mut stream)
	assert stream.in_flight_write_request()? == request
	writable_stream_finish_in_flight_write(mut stream)
	assert request.state() == .fulfilled
	assert !writable_stream_has_operation_marked_in_flight(stream)
	sentinel := create_close_sentinel()
	assert is_close_sentinel(sentinel)
	assert !is_close_sentinel(string_value('close'))
}

fn test_writable_controller_uses_queue_for_backpressure_and_resets_setup_state() {
	mut stream := WritableStream{
		started_: true
		backpressure_: false
	}
	stream.queue_.enqueue_value_with_size(string_value('stale'), 3)!
	mut controller := WritableStreamDefaultController{}
	set_up_writable_stream_default_controller(mut stream, mut controller, upstream_test_start, upstream_test_write, upstream_test_close, upstream_test_abort, 1, count_size_algorithm)!
	assert controller.started()
	assert controller.queue().len == 0
	assert !writable_stream_default_controller_get_backpressure(controller)

	stream.queue_.enqueue_value_with_size(string_value('queued'), 1)!
	assert writable_stream_default_controller_get_backpressure(controller)
	controller.set_queue_total_size(-3)
	assert controller.queue_total_size() == -3
}

fn test_writable_controller_setup_propagates_start_exception_synchronously() {
	mut stream := WritableStream{}
	initialize_writable_stream(mut stream)
	mut controller := WritableStreamDefaultController{}
	set_up_writable_stream_default_controller(mut stream, mut controller, upstream_test_failing_start, upstream_test_write, upstream_test_close, upstream_test_abort, 1, count_size_algorithm) or {
		assert err.msg() == 'setup start failed'
		assert stream.state() == .writable
		assert !controller.started()
		return
	}
	assert false
}

fn test_writable_close_clears_controller_algorithms() {
	mut stream := create_writable_stream(upstream_test_start, upstream_test_write, upstream_test_close, upstream_test_abort, 1, count_size_algorithm)!
	mut writer := acquire_writable_stream_default_writer(mut stream)!
	assert writable_stream_default_writer_close(mut writer).state() == .fulfilled
	if _ := stream.controller().write_algorithm() {
		assert false
	}
	if _ := stream.controller().close_algorithm() {
		assert false
	}
	if _ := stream.controller().abort_algorithm() {
		assert false
	}
	assert writable_stream_default_writer_close_with_error_propagation(mut writer).state() == .fulfilled
}

fn test_transform_slots_and_cross_realm_endpoints() {
	mut transform := TransformStream.construct_impl(Transformer{}, QueuingStrategy{}, QueuingStrategy{
		high_water_mark: 1
	})!
	changed := transform.backpressure_change_promise()
	transform.set_backpressure(!transform.backpressure())
	assert changed.state() == .fulfilled
	assert transform.backpressure_change_promise().state() == .pending

	mut readable := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	mut port := MessagePort.create()
	set_up_cross_realm_transform_readable(mut readable, mut port)
	mut writable := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	set_up_cross_realm_transform_writable(mut writable, mut port)
	mut writer := writable.get_writer()!
	write := writer.write(string_value('across'))
	assert write.state() == .pending
	mut reader := readable.get_default_reader()!
	assert reader.read().result().value.text == 'across'
	assert write.state() == .fulfilled
	assert port.messages().map(it.type_) == ['pull', 'chunk']
	assert writer.close().state() == .fulfilled
	assert reader.read().result().done
	assert port.messages().map(it.type_) == ['pull', 'chunk', 'close']
}

fn test_cross_realm_endpoint_cancellation_propagates_to_the_other_side() {
	mut cancelled_readable := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	mut cancel_port := MessagePort.create()
	set_up_cross_realm_transform_readable(mut cancelled_readable, mut cancel_port)
	mut cancelled_writable := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	set_up_cross_realm_transform_writable(mut cancelled_writable, mut cancel_port)
	mut cancel_reader := cancelled_readable.get_default_reader()!
	mut cancel_writer := cancelled_writable.get_writer()!
	assert cancel_reader.cancel(string_value('consumer stopped')).state() == .fulfilled
	assert cancelled_writable.state() == .errored
	assert cancelled_writable.stored_error() == 'consumer stopped'
	assert cancel_writer.closed().state() == .rejected
	assert cancel_port.messages().map(it.type_) == ['error']

	mut aborted_readable := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	mut abort_port := MessagePort.create()
	set_up_cross_realm_transform_readable(mut aborted_readable, mut abort_port)
	mut aborted_writable := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	set_up_cross_realm_transform_writable(mut aborted_writable, mut abort_port)
	mut abort_reader := aborted_readable.get_default_reader()!
	mut abort_writer := aborted_writable.get_writer()!
	assert abort_writer.abort(string_value('producer stopped')).state() == .fulfilled
	assert aborted_readable.state() == .errored
	assert aborted_readable.stored_error() == 'producer stopped'
	assert abort_reader.closed().state() == .rejected
	assert abort_port.messages().map(it.type_) == ['error']
}

fn test_pipe_operation_and_stream_pair_indexing() {
	mut source := ReadableStream.from([number_value(9)])!
	mut destination := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	pipe_result := readable_stream_pipe_to(mut source, mut destination, false, false, false, none)
	assert pipe_result.state() == .fulfilled
	assert destination.written_values()[0].number == 9

	mut tee_source := ReadableStream.from([string_value('x')])!
	pair := readable_stream_tee(mut tee_source, true)!
	assert pair.size() == 2
	assert pair.at(0)! == pair.first
	assert pair.at(1)! == pair.second
}
