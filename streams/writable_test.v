module streams

fn failing_write(_ Value) ! {
	return error('write failed')
}

fn failing_start() ! {
	return error('start failed')
}

fn negative_size(_ Value) !f64 {
	return -1
}

fn failing_abort(_ Value) ! {
	return error('abort failed')
}

fn test_writable_writer_lock_write_and_close() {
	mut stream := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	mut writer := stream.get_writer()!
	assert stream.locked()
	assert stream.close().state() == .rejected
	assert writer.ready().state() == .fulfilled
	assert writer.desired_size()? == 1
	assert writer.write(string_value('one')).state() == .fulfilled
	assert stream.written_values().map(it.text) == ['one']
	assert writer.close().state() == .fulfilled
	assert stream.state() == .closed
	assert writer.closed().state() == .fulfilled
	assert writer.write(string_value('late')).state() == .rejected
}

fn test_writer_release_unlocks_and_rejects_its_promises() {
	mut stream := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	mut writer := stream.get_writer()!
	writer.release_lock()
	assert !stream.locked()
	assert writer.closed().state() == .rejected
	assert writer.write(undefined_value()).state() == .rejected
	assert stream.close().state() == .fulfilled
}

fn test_writer_ready_is_fulfilled_after_close_at_zero_high_water_mark() {
	mut stream := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{
		high_water_mark: 0
	})!
	mut writer := stream.get_writer()!
	ready := writer.ready()
	assert ready.state() == .pending
	assert writer.close().state() == .fulfilled
	assert ready.state() == .fulfilled
	assert writer.ready().state() == .fulfilled
	writer.release_lock()
	assert writer.ready().state() == .rejected
	assert writer.closed().state() == .rejected
}

fn test_write_failure_errors_stream_without_signaling_abort() {
	mut stream := WritableStream.construct_impl(UnderlyingSink{
		write: failing_write
	}, QueuingStrategy{})!
	mut writer := stream.get_writer()!
	ready := writer.ready()
	result := writer.write(number_value(1))
	assert result.state() == .rejected
	assert result.reason() == 'write failed'
	assert stream.state() == .errored
	assert !stream.controller().signal().aborted()
	assert ready.state() == .fulfilled
	assert writer.ready().state() == .rejected
	assert writer.closed().state() == .rejected
}

fn test_start_and_size_failures_error_writable_stream() {
	if _ := WritableStream.construct_impl(UnderlyingSink{
		start: failing_start
	}, QueuingStrategy{}) {
		assert false
	} else {
		assert err.msg() == 'start failed'
	}
	mut sized := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{
		size: negative_size
	})!
	mut writer := sized.get_writer()!
	assert writer.write(string_value('bad')).state() == .rejected
	assert sized.state() == .errored
}

fn test_controller_error_and_writer_abort() {
	mut stream := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	mut controller := stream.controller()
	controller.error('controller failure')
	assert stream.state() == .errored
	assert stream.stored_error() == 'controller failure'

	mut aborted := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	mut writer := aborted.get_writer()!
	result := writer.abort(string_value('stop'))
	assert result.state() == .fulfilled
	assert aborted.state() == .errored
	assert aborted.controller().signal().reason().text == 'stop'
}

fn test_writable_requests_follow_in_flight_and_close_sentinel_lifecycle() {
	mut stream := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	mut writer := stream.get_writer()!
	write := writer.write(string_value('one'))
	assert write.state() == .fulfilled
	assert stream.write_requests_.len == 0
	assert isnil(stream.in_flight_write_request_)
	assert stream.queue_.is_empty()

	close := writer.close()
	assert close.state() == .fulfilled
	assert stream.state() == .closed
	assert isnil(stream.close_request_)
	assert isnil(stream.in_flight_close_request_)
	assert stream.queue_.is_empty()
}

fn test_abort_rejection_replaces_abort_result_and_clears_algorithms() {
	mut stream := WritableStream.construct_impl(UnderlyingSink{
		abort: failing_abort
	}, QueuingStrategy{})!
	result := stream.abort(string_value('stop'))
	assert result.state() == .rejected
	assert result.reason() == 'abort failed'
	assert stream.state() == .errored
	assert stream.controller().signal().aborted()
	if _ := stream.controller().abort_algorithm() {
		assert false
	}
	if _ := stream.controller().write_algorithm() {
		assert false
	}
	if _ := stream.controller().close_algorithm() {
		assert false
	}
	assert stream.abort(string_value('again')).state() == .fulfilled
}

fn test_underlying_sink_type_is_rejected() {
	if _ := WritableStream.construct_impl(UnderlyingSink{
		type_: 'bytes'
	}, QueuingStrategy{}) {
		assert false
	} else {
		assert err.msg().contains('Unsupported')
	}
}
