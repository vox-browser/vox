module streams

fn pipe_uppercase_transform(value Value) ![]Value {
	return [string_value(value.text.to_upper())]
}

fn require_ordered_tee_cancel(reason Value) ! {
	if reason.kind != .array || reason.items.len != 2 || reason.items[0].text != 'one' || reason.items[1].text != 'two' {
		return error('tee reasons are out of branch order')
	}
}

fn pipe_failing_abort(_ Value) ! {
	return error('abort action failed')
}

fn pipe_failing_cancel(_ Value) ! {
	return error('cancel action failed')
}

fn test_pipe_to_drains_closes_and_releases_locks() {
	mut source := ReadableStream.from([string_value('a'), string_value('b')])!
	mut destination := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	result := source.pipe_to(mut destination, StreamPipeOptions{})
	assert result.state() == .fulfilled
	assert destination.written_values().map(it.text) == ['a', 'b']
	assert destination.state() == .closed
	assert !source.locked()
	assert !destination.locked()
}

fn test_open_pipe_pumps_future_chunks_and_honors_prevent_close() {
	mut source := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	mut destination := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	result := source.pipe_to(mut destination, StreamPipeOptions{
		prevent_close: true
	})
	assert result.state() == .pending
	mut controller := source.default_controller()!
	controller.enqueue(number_value(7))!
	assert destination.written_values()[0].number == 7
	controller.close()!
	assert result.state() == .fulfilled
	assert destination.state() == .writable
}

fn test_pipe_marks_source_disturbed_and_uses_a_read_request() {
	mut source := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{
		high_water_mark: 0
	})!
	mut destination := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	result := source.pipe_to(mut destination, StreamPipeOptions{})
	assert result.state() == .pending
	assert source.disturbed()
	assert source.pending_reads_.len == 1
	assert !isnil(source.pipe_read_request_)

	mut controller := source.default_controller()!
	controller.enqueue(string_value('requested'))!
	assert destination.written_values().map(it.text) == ['requested']
	assert source.pending_reads_.len == 1
	controller.close()!
	assert result.state() == .fulfilled
}

fn test_pipe_rejects_and_cancels_when_destination_is_already_closed() {
	mut source := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	mut destination := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	assert destination.close().state() == .fulfilled
	result := source.pipe_to(mut destination, StreamPipeOptions{})
	assert result.state() == .rejected
	assert result.reason() == 'TypeError: Destination stream was closed during piping operation'
	assert source.state() == .closed
	assert !source.locked()
	assert !destination.locked()
}

fn test_aborted_pipe_aborts_destination_and_cancels_source() {
	mut source := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	mut destination := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	mut signal := AbortSignal.create()
	signal.abort(string_value('abort pipe'))
	result := source.pipe_to(mut destination, StreamPipeOptions{
		signal: signal
	})
	assert result.state() == .rejected
	assert source.state() == .closed
	assert destination.state() == .errored
}

fn test_abort_signal_stops_an_already_running_pipe() {
	mut source := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	mut destination := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	mut signal := AbortSignal.create()
	result := source.pipe_to(mut destination, StreamPipeOptions{
		signal: signal
	})
	assert result.state() == .pending
	signal.abort(string_value('later abort'))
	assert result.state() == .rejected
	assert source.state() == .closed
	assert destination.state() == .errored
}

fn test_direct_close_and_byte_error_settle_open_pipes() {
	mut source := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	mut destination := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	closed := source.pipe_to(mut destination, StreamPipeOptions{})
	source.close()
	assert closed.state() == .fulfilled
	assert destination.state() == .closed

	mut byte_source := ReadableStream.construct_impl(UnderlyingSource{
		type_: .bytes
	}, QueuingStrategy{})!
	mut byte_destination := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	failed := byte_source.pipe_to(mut byte_destination, StreamPipeOptions{})
	mut byte_controller := byte_source.byte_controller()!
	byte_controller.error('byte source failed')
	assert failed.state() == .rejected
	assert failed.reason() == 'byte source failed'
	assert byte_destination.state() == .errored
}

fn test_destination_error_rejects_an_open_pipe_and_cancels_source() {
	mut source := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	mut destination := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	result := source.pipe_to(mut destination, StreamPipeOptions{})
	mut destination_controller := destination.controller()
	destination_controller.error('destination failed')
	assert result.state() == .rejected
	assert result.reason() == 'destination failed'
	assert source.state() == .closed
	assert !source.locked()
	assert !destination.locked()
}

fn test_pipe_releases_byte_controller_auto_allocate_descriptor() {
	mut source := ReadableStream.construct_impl(UnderlyingSource{
		type_: .bytes
		auto_allocate_chunk_size: u64(4)
	}, QueuingStrategy{})!
	mut destination := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	result := source.pipe_to(mut destination, StreamPipeOptions{
		prevent_cancel: true
	})
	assert result.state() == .pending
	mut source_controller := source.byte_controller()!
	assert source_controller.pending_pull_intos().first().reader_type == .default_reader

	mut destination_controller := destination.controller()
	destination_controller.error('destination failed')
	assert result.state() == .rejected
	assert !source.locked()
	assert source_controller.pending_pull_intos().first().reader_type == .none
}

fn test_pipe_shutdown_uses_action_rejection_and_releases_pending_read() {
	mut failed_source := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	mut aborting_destination := WritableStream.construct_impl(UnderlyingSink{
		abort: pipe_failing_abort
	}, QueuingStrategy{})!
	mut failed_controller := failed_source.default_controller()!
	failed_controller.error('source failed')
	forward := failed_source.pipe_to(mut aborting_destination, StreamPipeOptions{})
	assert forward.state() == .rejected
	assert forward.reason() == 'abort action failed'

	mut canceling_source := ReadableStream.construct_impl(UnderlyingSource{
		cancel: pipe_failing_cancel
	}, QueuingStrategy{})!
	mut failed_destination := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	backward := canceling_source.pipe_to(mut failed_destination, StreamPipeOptions{})
	assert canceling_source.pending_reads_.len == 1
	mut destination_controller := failed_destination.controller()
	destination_controller.error('destination failed')
	assert backward.state() == .rejected
	assert backward.reason() == 'cancel action failed'
	assert canceling_source.pending_reads_.len == 0
	assert isnil(canceling_source.pipe_read_request_)
}

fn test_pipe_through_returns_transform_readable() {
	mut source := ReadableStream.from([string_value('x')])!
	transform := TransformStream.construct_impl(Transformer{
		transform: pipe_uppercase_transform
	}, QueuingStrategy{}, QueuingStrategy{
		high_water_mark: 2
	})!
	mut readable := source.pipe_through(ReadableWritablePair{
		readable: transform.readable()
		writable: transform.writable()
	}, StreamPipeOptions{})!
	mut reader := readable.get_default_reader()!
	assert reader.read().result().value.text == 'X'
}

fn test_tee_clones_chunks_and_waits_for_both_cancellations() {
	mut source := ReadableStream.construct_impl(UnderlyingSource{
		cancel: require_ordered_tee_cancel
	}, QueuingStrategy{})!
	pair := source.tee()!
	mut controller := source.default_controller()!
	mut bytes := [u8(1), 2]
	controller.enqueue(bytes_value(bytes))!
	mut first := pair.first
	mut second := pair.second
	mut first_reader := first.get_default_reader()!
	mut second_reader := second.get_default_reader()!
	first_result := first_reader.read().result()
	second_result := second_reader.read().result()
	assert first_result.value.bytes_ == [u8(1), 2]
	assert second_result.value.bytes_ == [u8(1), 2]
	mut first_value := first_result.value
	first_value.bytes_[0] = 9
	assert bytes == [u8(9), 2]
	assert second_result.value.bytes_ == [u8(1), 2]
	first_reader.release_lock()!
	second_reader.release_lock()!
	first_cancel := first.cancel(string_value('one'))
	assert first_cancel.state() == .pending
	second_cancel := second.cancel(string_value('two'))
	assert first_cancel.state() == .fulfilled
	assert second_cancel.state() == .fulfilled
	assert source.state() == .closed
}

fn test_default_tee_pulls_on_demand_instead_of_eagerly_copying_source_queue() {
	mut source := ReadableStream.from([
		string_value('one'),
		string_value('two'),
		string_value('three'),
	])!
	pair := source.tee()!
	assert source.queued_chunks() == 0
	assert source.from_index_ == 1
	assert pair.first.queued_chunks() == 1
	assert pair.second.queued_chunks() == 1

	mut first := pair.first
	mut reader := first.get_default_reader()!
	assert reader.read().result().value.text == 'one'
	assert source.from_index_ == 2
	assert pair.second.queued_chunks() == 2
}

fn test_byte_tee_waits_for_branch_demand_and_fulfills_byob_reads() {
	mut source := ReadableStream.construct_impl(UnderlyingSource{
		type_: .bytes
	}, QueuingStrategy{})!
	mut source_controller := source.byte_controller()!
	source_controller.enqueue([u8(1), 2, 3])!
	pair := source.tee()!
	assert source.queued_chunks() == 1
	assert pair.first.queued_chunks() == 0
	assert pair.second.queued_chunks() == 0

	mut first := pair.first
	mut reader := first.get_byob_reader()!
	read := reader.read(4, 1)
	assert read.state() == .fulfilled
	assert read.result().value == [u8(1), 2, 3]
	assert source.queued_chunks() == 0
	assert pair.second.queued_chunks() == 1
}

fn test_byte_tee_byob_demand_uses_the_branch_view_for_the_source_read() {
	mut source := ReadableStream.construct_impl(UnderlyingSource{
		type_: .bytes
	}, QueuingStrategy{})!
	pair := source.tee()!
	mut first := pair.first
	mut reader := first.get_byob_reader()!
	pending := reader.read(4, 1)
	assert pending.state() == .pending
	assert source.reader_kind_ == .byob

	mut source_controller := source.byte_controller()!
	mut source_request := source_controller.byob_request() or {
		panic('byte tee did not expose the requesting branch BYOB view to the source')
	}
	source_request.write_view([u8(8), 9])!
	mut branch_controller := first.byte_controller()!
	branch_request := branch_controller.byob_request() or {
		panic('requesting branch lost its BYOB request')
	}
	assert branch_request.view()?[..2] == [u8(8), 9]

	source_request.respond(2)!
	assert pending.state() == .fulfilled
	assert pending.result().value == [u8(8), 9]
	assert pair.second.queued_chunks() == 1
}

fn test_source_close_settles_a_single_tee_cancellation() {
	mut source := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	pair := source.tee()!
	mut first := pair.first
	first_cancel := first.cancel(string_value('one'))
	assert first_cancel.state() == .pending
	mut controller := source.default_controller()!
	controller.close()!
	assert first_cancel.state() == .fulfilled
	assert pair.second.state() == .closed
}

fn test_source_error_fulfills_a_single_tee_cancellation_and_errors_the_other_branch() {
	mut source := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	pair := source.tee()!
	mut first := pair.first
	first_cancel := first.cancel(string_value('one'))
	mut controller := source.default_controller()!
	controller.error('source failed')
	assert first_cancel.state() == .fulfilled
	assert pair.second.state() == .errored
}

fn test_readable_transfer_moves_existing_and_future_chunks() {
	mut source := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	mut controller := source.default_controller()!
	controller.enqueue(string_value('before'))!
	mut proxy := source.transfer()!
	assert source.locked()
	assert proxy.queued_chunks() == 0
	controller.enqueue(string_value('after'))!
	assert source.queued_chunks() == 1
	controller.close()!
	mut reader := proxy.get_default_reader()!
	assert reader.read().result().value.text == 'before'
	assert reader.read().result().value.text == 'after'
	assert reader.read().result().done
}

fn test_writable_transfer_forwards_operations_and_locks_original() {
	mut destination := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	mut proxy := destination.transfer()!
	assert destination.locked()
	mut writer := proxy.get_writer()!
	assert writer.write(string_value('forwarded')).state() == .fulfilled
	assert destination.written_values()[0].text == 'forwarded'
	assert writer.close().state() == .fulfilled
	assert destination.state() == .closed
}

fn test_transfer_receiving_steps_rebind_controllers_to_destination_streams() {
	mut readable_source := ReadableStream.from([string_value('received')])!
	mut readable_destination := ReadableStream{}
	readable_destination.transfer_receiving_steps(mut readable_source)!
	assert readable_destination.default_controller()!.stream() == &readable_destination
	mut reader := readable_destination.get_default_reader()!
	assert reader.read().result().value.text == 'received'

	mut writable_source := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	mut writable_destination := WritableStream{}
	writable_destination.transfer_receiving_steps(mut writable_source)!
	assert writable_destination.controller().stream() == &writable_destination
	mut writer := writable_destination.get_writer()!
	assert writer.write(string_value('received')).state() == .fulfilled
	assert writable_source.written_values()[0].text == 'received'
}
