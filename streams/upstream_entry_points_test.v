module streams

fn upstream_test_start() ! {}
fn upstream_test_pull() ! {}
fn upstream_test_cancel(_ Value) ! {}
fn upstream_test_write(_ Value) ! {}
fn upstream_test_close() ! {}
fn upstream_test_abort(_ Value) ! {}

fn test_readable_abstract_operations_share_controller_state() {
	mut stream := create_readable_stream(upstream_test_start, upstream_test_pull,
		upstream_test_cancel, 2.0, count_size_algorithm)!
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

fn test_byte_controller_entry_points_fill_byob_request() {
	mut stream := create_readable_byte_stream(upstream_test_start, upstream_test_pull,
		upstream_test_cancel)!
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
	mut stream := create_writable_stream(upstream_test_start, upstream_test_write,
		upstream_test_close, upstream_test_abort, 1, count_size_algorithm)!
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

fn test_transform_slots_and_cross_realm_endpoints() {
	mut transform := TransformStream.construct_impl(Transformer{}, QueuingStrategy{},
		QueuingStrategy{
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
	assert writer.write(string_value('across')).state() == .fulfilled
	assert writer.close().state() == .fulfilled
	mut reader := readable.get_default_reader()!
	assert reader.read().result().value.text == 'across'
	assert reader.read().result().done
}

fn test_pipe_operation_and_stream_pair_indexing() {
	mut source := ReadableStream.from([number_value(9)])!
	mut destination := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	mut operation := ReadableStreamPipeTo.create(mut source, mut destination,
		StreamPipeOptions{})!
	operation.process()
	assert operation.promise_.state() == .fulfilled
	assert destination.written_values()[0].number == 9

	mut tee_source := ReadableStream.from([string_value('x')])!
	pair := readable_stream_tee(mut tee_source, true)!
	assert pair.size() == 2
	assert pair.at(0)! == pair.first
	assert pair.at(1)! == pair.second
}
