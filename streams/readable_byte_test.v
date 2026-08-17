module streams

fn new_byte_stream() !&ReadableStream {
	return ReadableStream.construct_impl(UnderlyingSource{
		type_: .bytes
	}, QueuingStrategy{})
}

fn test_byte_stream_rejects_size_strategy_and_zero_auto_allocate() {
	if _ := ReadableStream.construct_impl(UnderlyingSource{
		type_: .bytes
	}, QueuingStrategy{
		size: count_size_algorithm
	})
	{
		assert false
	} else {
		assert err.msg().contains('size function')
	}
	if _ := ReadableStream.construct_impl(UnderlyingSource{
		type_:                    .bytes
		auto_allocate_chunk_size: u64(0)
	}, QueuingStrategy{})
	{
		assert false
	} else {
		assert err.msg().contains('greater than zero')
	}
}

fn test_byob_reader_splits_queued_byte_chunks() {
	mut stream := new_byte_stream()!
	mut controller := stream.byte_controller()!
	controller.enqueue([u8(1), 2, 3, 4, 5])!
	mut reader := stream.get_byob_reader()!
	first := reader.read(3, 2)
	assert first.state() == .fulfilled
	assert first.result().value == [u8(1), 2, 3]
	second := reader.read(4, 2)
	assert second.result().value == [u8(4), 5]
	assert stream.queue_total_size() == 0
}

fn test_pending_byob_request_respond_and_invalidation() {
	mut stream := new_byte_stream()!
	mut reader := stream.get_byob_reader()!
	pending := reader.read(4, 2)
	assert pending.state() == .pending
	mut controller := stream.byte_controller()!
	mut request := controller.byob_request() or { panic('missing request') }
	assert request.view()?.len == 4
	request.write_view([u8(8), 9])!
	request.respond(2)!
	assert pending.state() == .fulfilled
	assert pending.result().value == [u8(8), 9]
	assert request.view() == none
	if _ := request.respond(0) {
		assert false
	} else {
		assert err.msg().contains('inactive')
	}
}

fn test_queued_prefix_is_combined_with_byob_response() {
	mut stream := new_byte_stream()!
	mut controller := stream.byte_controller()!
	controller.enqueue([u8(1)])!
	mut reader := stream.get_byob_reader()!
	pending := reader.read(4, 3)
	assert pending.state() == .pending
	mut request := controller.byob_request() or { panic('missing request') }
	assert request.view()?.len == 3
	request.respond_with_new_view([u8(2), 3])!
	assert pending.result().value == [u8(1), 2, 3]
}

fn test_byob_validation_release_and_close_rules() {
	mut stream := new_byte_stream()!
	mut reader := stream.get_byob_reader()!
	assert reader.read(0, 1).state() == .rejected
	assert reader.read(2, 0).state() == .rejected
	assert reader.read(2, 3).reason().contains('exceeds')
	pending := reader.read(4, 3)
	mut controller := stream.byte_controller()!
	mut request := controller.byob_request() or { panic('missing request') }
	reader.release_lock()!
	assert pending.state() == .rejected
	assert pending.reason().contains('released')
	assert request.view() == none
	assert !stream.locked()
	if _ := request.respond(0) {
		assert false
	} else {
		assert err.msg().contains('inactive')
	}

	mut second_reader := stream.get_byob_reader()!
	controller.enqueue([u8(1)])!
	second_pending := second_reader.read(4, 3)
	if _ := controller.close() {
		assert false
	} else {
		assert err.msg().contains('Insufficient')
	}
	controller.enqueue([u8(2), 3])!
	assert second_pending.result().value == [u8(1), 2, 3]
	controller.close()!
	second_reader.release_lock()!
}

fn test_close_invalidates_a_pending_byob_request() {
	mut stream := new_byte_stream()!
	mut reader := stream.get_byob_reader()!
	pending := reader.read(4, 1)
	mut controller := stream.byte_controller()!
	mut request := controller.byob_request() or { panic('missing request') }
	controller.close()!
	assert pending.state() == .fulfilled
	assert pending.result().done
	assert request.view() == none
	if _ := request.respond(0) {
		assert false
	} else {
		assert err.msg().contains('inactive')
	}
}

fn test_release_preserves_bytes_already_taken_into_a_byob_descriptor() {
	mut stream := new_byte_stream()!
	mut controller := stream.byte_controller()!
	controller.enqueue([u8(1), 2])!
	mut reader := stream.get_byob_reader()!
	pending := reader.read(4, 3)
	assert pending.state() == .pending
	reader.release_lock()!
	assert pending.state() == .rejected
	mut replacement := stream.get_byob_reader()!
	read := replacement.read(2, 2)
	assert read.state() == .fulfilled
	assert read.result().value == [u8(1), 2]
}

fn test_default_reader_can_consume_byte_stream_chunks() {
	mut stream := new_byte_stream()!
	mut controller := stream.byte_controller()!
	controller.enqueue([u8(4), 5])!
	controller.close()!
	mut reader := stream.get_default_reader()!
	assert reader.read_all_bytes()! == [u8(4), 5]
}

fn test_auto_allocate_exposes_byob_request_for_default_reader() {
	mut stream := ReadableStream.construct_impl(UnderlyingSource{
		type_:                    .bytes
		auto_allocate_chunk_size: u64(4)
	}, QueuingStrategy{})!
	reader_union := stream.get_reader(ReadableStreamGetReaderOptions{})!
	assert reader_union.kind == .default_reader
	mut reader := reader_union.default_reader
	pending := reader.read()
	mut controller := stream.byte_controller()!
	assert stream.current_byob_request_view()?.len == 4
	mut request := controller.byob_request() or { panic('missing auto-allocated request') }
	request.write_view([u8(6), 7])!
	request.respond(2)!
	assert pending.result().value.bytes_ == [u8(6), 7]
}
