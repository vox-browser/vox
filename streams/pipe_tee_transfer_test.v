module streams

fn pipe_uppercase_transform(value Value) ![]Value {
	return [string_value(value.text.to_upper())]
}

fn require_ordered_tee_cancel(reason Value) ! {
	if reason.kind != .array || reason.items.len != 2 || reason.items[0].text != 'one'
		|| reason.items[1].text != 'two' {
		return error('tee reasons are out of branch order')
	}
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
	bytes[0] = 9
	mut first := pair.first
	mut second := pair.second
	mut first_reader := first.get_default_reader()!
	mut second_reader := second.get_default_reader()!
	assert first_reader.read().result().value.bytes_ == [u8(1), 2]
	assert second_reader.read().result().value.bytes_ == [u8(1), 2]
	first_reader.release_lock()!
	second_reader.release_lock()!
	first_cancel := first.cancel(string_value('one'))
	assert first_cancel.state() == .pending
	second_cancel := second.cancel(string_value('two'))
	assert first_cancel.state() == .fulfilled
	assert second_cancel.state() == .fulfilled
	assert source.state() == .closed
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

fn test_source_error_rejects_a_single_tee_cancellation() {
	mut source := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	pair := source.tee()!
	mut first := pair.first
	first_cancel := first.cancel(string_value('one'))
	mut controller := source.default_controller()!
	controller.error('source failed')
	assert first_cancel.state() == .rejected
	assert first_cancel.reason() == 'source failed'
	assert pair.second.state() == .errored
}

fn test_readable_transfer_moves_existing_and_future_chunks() {
	mut source := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	mut controller := source.default_controller()!
	controller.enqueue(string_value('before'))!
	mut proxy := source.transfer()!
	assert source.locked()
	controller.enqueue(string_value('after'))!
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
