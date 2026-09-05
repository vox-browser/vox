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
	}) {
		assert false
	} else {
		assert err.msg().contains('size function')
	}
	if _ := ReadableStream.construct_impl(UnderlyingSource{
		type_: .bytes
		auto_allocate_chunk_size: u64(0)
	}, QueuingStrategy{}) {
		assert false
	} else {
		assert err.msg().contains('chunk size of 0')
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

fn test_partial_byob_read_advances_the_byte_queue_entry() {
	mut stream := new_byte_stream()!
	mut controller := stream.byte_controller()!
	controller.enqueue([u8(1), 2, 3, 4, 5])!
	before := controller.queue()[0]
	backing_store := voidptr(before.buffer.data_.data)

	mut reader := stream.get_byob_reader()!
	first := reader.read(2, 2)
	assert first.result().value == [u8(1), 2]
	after := controller.queue()[0]
	assert after.byte_offset == 2
	assert after.byte_length == 3
	assert voidptr(after.buffer.data_.data) == backing_store
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
		assert err.msg().contains('undefined')
	}
}

fn test_pull_from_bytes_limits_the_pull_to_the_active_byob_view() {
	mut stream := ReadableStream.construct_impl(UnderlyingSource{
		type_: .bytes
	}, QueuingStrategy{})!
	mut reader := stream.get_byob_reader()!
	pending := reader.read(2, 1)
	assert pending.state() == .pending
	stream.pull_from_bytes([u8(1), 2, 3, 4])!
	assert pending.state() == .fulfilled
	assert pending.result().value == [u8(1), 2]
	assert stream.queued_chunks() == 0
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

fn test_byob_validation_and_release_rules() {
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
	// C++ keeps the first pull-into descriptor and its BYOB request alive after
	// release so bytes already written by the source can return to the queue.
	assert request.view()?.len == 4
	assert !stream.locked()
	request.write_view([u8(7), 8])!
	request.respond(2)!
	mut replacement := stream.get_byob_reader()!
	read := replacement.read(2, 2)
	assert read.state() == .fulfilled
	assert read.result().value == [u8(7), 8]
}

fn test_close_waits_for_zero_response_to_finish_pending_byob_request() {
	mut stream := new_byte_stream()!
	mut reader := stream.get_byob_reader()!
	pending := reader.read(4, 1)
	mut controller := stream.byte_controller()!
	mut request := controller.byob_request() or { panic('missing request') }
	controller.close()!
	assert pending.state() == .pending
	assert request.view()?.len == 4
	request.respond(0)!
	assert pending.state() == .fulfilled
	assert pending.result().done
	assert request.view() == none
	if _ := request.respond(0) {
		assert false
	} else {
		assert err.msg().contains('undefined')
	}
}

fn test_readable_stream_close_supplies_the_internal_zero_response() {
	mut stream := new_byte_stream()!
	mut reader := stream.get_byob_reader()!
	pending := reader.read(4, 1)
	mut controller := stream.byte_controller()!
	mut request := controller.byob_request() or { panic('missing request') }
	stream.close()
	assert pending.state() == .fulfilled
	assert pending.result().done
	assert request.view() == none
}

fn test_close_commits_aligned_partial_data_and_errors_on_misalignment() {
	mut stream := new_byte_stream()!
	mut controller := stream.byte_controller()!
	controller.enqueue([u8(1)])!
	mut reader := stream.get_byob_reader()!
	pending := reader.read(4, 3)
	mut request := controller.byob_request() or { panic('missing request') }
	controller.close()!
	assert pending.state() == .pending
	request.respond(0)!
	assert pending.result().done
	assert pending.result().value == [u8(1)]

	mut misaligned := new_byte_stream()!
	mut misaligned_controller := misaligned.byte_controller()!
	misaligned_controller.pending_pull_intos_.append(PullIntoDescriptor{
		buffer: ArrayBuffer.from_bytes([u8(1), 0, 0, 0])
		buffer_byte_length: 4
		byte_length: 4
		bytes_filled: 1
		minimum_fill: 2
		element_size: 2
		reader_type: .byob
	})
	if _ := misaligned_controller.close() {
		assert false
	} else {
		assert err.msg().contains('middle of processing')
	}
	assert misaligned.state() == .errored
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
	controller.enqueue([u8(3)])!
	assert read.state() == .fulfilled
	assert read.result().value == [u8(1), 2]
	assert stream.queue_total_size() == 1
}

fn test_multiple_byob_reads_and_partial_responses_follow_descriptor_order() {
	mut stream := new_byte_stream()!
	mut reader := stream.get_byob_reader()!
	first := reader.read(4, 3)
	second := reader.read(2, 2)
	assert first.state() == .pending
	assert second.state() == .pending
	mut controller := stream.byte_controller()!

	mut first_request := controller.byob_request() or { panic('missing first request') }
	first_request.write_view([u8(1)])!
	first_request.respond(1)!
	assert first.state() == .pending
	assert first_request.view() == none

	mut continued_request := controller.byob_request() or { panic('missing continued request') }
	assert continued_request.view()?.len == 3
	continued_request.write_view([u8(2), 3])!
	continued_request.respond(2)!
	assert first.result().value == [u8(1), 2, 3]
	assert second.state() == .pending

	mut second_request := controller.byob_request() or { panic('missing second request') }
	second_request.write_view([u8(4), 5])!
	second_request.respond(2)!
	assert second.result().value == [u8(4), 5]
}

fn test_default_reader_can_consume_byte_stream_chunks() {
	mut stream := new_byte_stream()!
	mut controller := stream.byte_controller()!
	controller.enqueue([u8(4), 5])!
	controller.close()!
	mut reader := stream.get_default_reader()!
	assert reader.read_all_bytes()! == [u8(4), 5]
}

fn test_byte_queue_fulfills_the_removed_read_before_final_queue_drain_closes_stream() {
	mut stream := new_byte_stream()!
	mut reader := stream.get_default_reader()!
	pending := reader.read()
	assert pending.state() == .pending
	mut controller := stream.byte_controller()!
	buffer := ArrayBuffer.from_bytes([u8(7)])
	controller.append_byte_queue_entry(buffer, 0, 1)
	stream.close_requested_ = true

	readable_byte_stream_controller_process_read_requests_using_queue(mut controller)
	assert pending.state() == .fulfilled
	assert !pending.result().done
	assert pending.result().value.bytes_ == [u8(7)]
	assert stream.state() == .closed
}

fn test_auto_allocate_exposes_byob_request_for_default_reader() {
	mut stream := ReadableStream.construct_impl(UnderlyingSource{
		type_: .bytes
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

fn test_releasing_default_reader_marks_auto_allocated_pull_into_as_readerless() {
	mut stream := ReadableStream.construct_impl(UnderlyingSource{
		type_: .bytes
		auto_allocate_chunk_size: u64(4)
	}, QueuingStrategy{})!
	mut reader := stream.get_default_reader()!
	pending := reader.read()
	assert pending.state() == .pending
	mut controller := stream.byte_controller()!
	assert controller.pending_pull_intos().first().reader_type == .default_reader

	reader.release_lock()!
	assert pending.state() == .rejected
	assert !stream.locked()
	assert controller.pending_pull_intos().len == 1
	assert controller.pending_pull_intos().first().reader_type == .none
}
