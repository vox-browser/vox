module streams

fn size_two(_ Value) !f64 {
	return 2
}

fn failing_size(_ Value) !f64 {
	return error('size failed')
}

fn failing_pull() ! {
	return error('pull failed')
}

fn readable_failing_start() ! {
	return error('start failed')
}

fn failing_cancel(_ Value) ! {
	return error('cancel failed')
}

fn test_readable_from_default_reader_and_close_drain() {
	mut stream := ReadableStream.from([string_value('a'), string_value('b')])!
	assert stream.state() == .readable
	assert stream.queued_chunks() == 0
	mut reader := stream.get_default_reader()!
	assert stream.locked()
	assert stream.cancel(undefined_value()).state() == .rejected
	first := reader.read()
	assert first.state() == .fulfilled
	assert first.result().value.text == 'a'
	assert !first.result().done
	second := reader.read()
	assert second.result().value.text == 'b'
	assert stream.state() == .readable
	last := reader.read()
	assert last.result().done
	assert stream.state() == .closed
	assert reader.closed().state() == .fulfilled
}

fn test_pending_read_is_fulfilled_by_enqueue() {
	mut stream := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	mut reader := stream.get_default_reader()!
	pending := reader.read()
	assert pending.state() == .pending
	mut controller := stream.default_controller()!
	controller.enqueue(number_value(42))!
	assert pending.state() == .fulfilled
	assert pending.result().value.number == 42
	controller.close()!
	assert reader.closed().state() == .fulfilled
}

fn test_pending_reads_retain_source_linked_fifo_shape() {
	mut stream := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	mut reader := stream.get_default_reader()!
	mut reads := []&ReadPromise{cap: 4096}
	for _ in 0 .. 4096 {
		reads << reader.read()
	}
	assert stream.pending_reads_.len == 4096
	mut controller := stream.default_controller()!
	for index in 0 .. 4096 {
		controller.enqueue(number_value(index))!
	}
	for index, read in reads {
		assert read.result().value.number == index
	}
	assert stream.pending_reads_.len == 0
}

fn test_controller_desired_size_custom_size_and_error() {
	mut stream := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{
		high_water_mark: 3
		size: size_two
	})!
	mut controller := stream.default_controller()!
	assert controller.desired_size()? == 3
	controller.enqueue(string_value('x'))!
	assert controller.desired_size()? == 1
	controller.error('broken')
	assert stream.state() == .errored
	assert controller.desired_size() == none
	if _ := controller.enqueue(string_value('late')) {
		assert false
	}
}

fn test_start_and_pull_failures_error_the_stream() {
	if _ := ReadableStream.construct_impl(UnderlyingSource{
		start: readable_failing_start
	}, QueuingStrategy{}) {
		assert false
	} else {
		assert err.msg() == 'start failed'
	}

	stream := ReadableStream.construct_impl(UnderlyingSource{
		pull: failing_pull
	}, QueuingStrategy{})!
	assert stream.state() == .errored
	assert stream.stored_error() == 'pull failed'
}

fn test_release_lock_rejects_pending_read_and_unlocks() {
	mut stream := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	mut reader := stream.get_default_reader()!
	pending := reader.read()
	reader.release_lock()!
	assert pending.state() == .rejected
	assert pending.reason().contains('released')
	assert reader.closed().state() == .rejected
	assert !stream.locked()
}

fn test_release_lock_replaces_a_settled_closed_promise() {
	mut stream := ReadableStream.from([]Value{})!
	mut reader := stream.get_default_reader()!
	assert reader.closed().state() == .pending
	assert reader.read().result().done
	assert reader.closed().state() == .fulfilled
	reader.release_lock()!
	assert reader.closed().state() == .rejected
}

fn test_pending_read_skips_the_strategy_size_algorithm() {
	mut stream := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{
		size: failing_size
	})!
	mut reader := stream.get_default_reader()!
	pending := reader.read()
	mut controller := stream.default_controller()!
	controller.enqueue(number_value(42))!
	assert pending.state() == .fulfilled
	assert pending.result().value.number == 42
	assert stream.state() == .readable
	if _ := controller.enqueue(number_value(43)) {
		assert false
	} else {
		assert err.msg() == 'size failed'
	}
	assert stream.state() == .errored
}

fn test_default_source_ignores_auto_allocate_chunk_size() {
	stream := ReadableStream.construct_impl(UnderlyingSource{
		auto_allocate_chunk_size: u64(0)
	}, QueuingStrategy{})!
	assert !stream.is_byte_stream()
}

fn test_reader_cancel_propagates_underlying_rejection() {
	mut stream := ReadableStream.construct_impl(UnderlyingSource{
		cancel: failing_cancel
	}, QueuingStrategy{})!
	mut reader := stream.get_default_reader()!
	result := reader.cancel(string_value('stop'))
	assert result.state() == .rejected
	assert result.reason() == 'cancel failed'
	assert stream.state() == .closed
}

fn test_async_iterator_reads_and_return_obeys_prevent_cancel() {
	mut stream := ReadableStream.from([number_value(1)])!
	mut iterator := ReadableStreamAsyncIterator.create(mut stream, ReadableStreamIteratorOptions{})!
	assert iterator.next_iteration_result().result().value.number == 1
	assert iterator.next_iteration_result().result().done
	assert !stream.locked()

	mut open := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	mut protected_iterator := ReadableStreamAsyncIterator.create(mut open, ReadableStreamIteratorOptions{
		prevent_cancel: true
	})!
	assert protected_iterator.iterator_return(string_value('return')).state() == .fulfilled
	assert open.state() == .readable
}
