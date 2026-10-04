module streams

import webidl

@[heap]
struct ReadLoopJobs {
mut:
	jobs      []fn ()
	observed  []u8
	successes int
	failures  []webidl.Value
}

fn (mut observations ReadLoopJobs) drain() {
	mut count := 0
	for observations.jobs.len > 0 {
		count++
		assert count < 100
		job := observations.jobs[0]
		observations.jobs.delete(0)
		job()
	}
}

fn test_source_read_loop_pending_request_reuses_owner_across_chunks_and_closes_once() {
	mut observations := &ReadLoopJobs{}
	realm := StreamRealm.create(71)
	mut stream := ReadableStream.create(realm, UnderlyingSource{}, QueuingStrategy{})!
	mut reader := stream.get_default_reader()!
	reader.read_all_bytes_with_steps(fn [mut observations] (bytes []u8) {
		observations.observed = bytes
		observations.successes++
	}, fn [mut observations] (reason webidl.Value) {
		observations.failures << reason
	})
	assert stream.disturbed() && stream.locked()
	assert observations.successes == 0 && observations.failures.len == 0
	assert reader.read_requests().len == 1
	first := reader.read_requests()[0]
	mut controller := stream.default_controller()!
	controller.enqueue(bytes_value([u8(1), 2]))!
	assert reader.read_requests().len == 1
	assert reader.read_requests()[0] == first
	assert observations.successes == 0
	controller.enqueue(bytes_value([u8(3)]))!
	controller.close()!
	assert observations.observed == [u8(1), 2, 3]
	assert observations.successes == 1 && observations.failures.len == 0
	assert reader.read_requests().len == 0
	assert stream.locked() // Source does not release the aggregation reader.
	assert first is ReadLoopReadRequest
}

fn test_source_read_all_deprecated_returns_pending_owning_arraybuffer_promise_without_chunk_jobs() {
	mut observations := &ReadLoopJobs{}
	realm := StreamRealm.create_with_promise_context(webidl.PromiseContext{
		realm_id:      72
		job_scheduler: fn [mut observations] (job fn ()) { observations.jobs << job }
	})
	mut stream := ReadableStream.create(realm, UnderlyingSource{ type_: .bytes }, QueuingStrategy{})!
	mut reader := stream.get_default_reader()!
	mut result := reader.read_all_bytes_deprecated()
	assert result.state == .pending && webidl.promise_realm(result) == 72
	child := result.upon_fulfillment(fn [mut observations] (value webidl.Value) !webidl.Value {
		observations.observed = webidl.get_buffer_source_copy(value.buffer_value or { return error('Missing read-loop ArrayBuffer') })
		return value
	})
	mut controller := stream.byte_controller()!
	observations.drain()
	controller.enqueue([u8(4), 5])!
	observations.drain()
	assert result.state == .pending && observations.observed.len == 0
	controller.enqueue([u8(6)])!
	observations.drain()
	assert result.state == .pending && observations.observed.len == 0
	controller.close()!
	assert result.state == .fulfilled
	assert result.result.kind == .buffer_source
	assert result.result.buffer_value?.kind == .array_buffer
	assert webidl.get_buffer_source_copy(result.result.buffer_value?) == [u8(4), 5, 6]
	assert child.state == .pending && observations.observed.len == 0
	assert observations.jobs.len == 1
	observations.drain()
	assert child.state == .fulfilled && observations.observed == [u8(4), 5, 6]
}

fn test_source_read_loop_queued_last_chunk_closes_and_empty_closed_stream_succeeds() {
	for type_ in [UnderlyingSourceType.default_source, .bytes] {
		mut stream := ReadableStream.create(StreamRealm.create(73), UnderlyingSource{ type_: type_ }, QueuingStrategy{})!
		stream.enqueue(bytes_value([u8(7), 8]))!
		stream.enqueue(bytes_value([u8(9)]))!
		stream.close()
		mut reader := stream.get_default_reader()!
		result := reader.read_all_bytes_deprecated()
		assert result.state == .fulfilled
		assert webidl.get_buffer_source_copy(result.result.buffer_value?) == [u8(7), 8, 9]
		assert reader.read_requests().len == 0 && stream.is_closed()
	}
	mut empty := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	empty.close()
	mut reader := empty.get_default_reader()!
	result := reader.read_all_bytes_deprecated()
	assert result.state == .fulfilled
	assert webidl.get_buffer_source_copy(result.result.buffer_value?).len == 0
}

fn test_source_read_loop_preserves_actual_stored_error_and_rejects_non_uint8_chunks() {
	mut stream := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	mut reader := stream.get_default_reader()!
	result := reader.read_all_bytes_deprecated()
	exception := webidl.DOMException.create_record('AbortError', 'original')
	reason := webidl.dom_exception_value_for_record(exception)
	stream.error_value(reason)
	assert result.state == .rejected
	assert result.result.dom_exception_? == exception
	for chunk in [string_value('bad'), runtime_value(webidl.buffer_source_value(webidl.BufferSource.view(.uint16_array, [
		u8(1),
		2,
	], 0, 2)!))] {
		mut source := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
		mut owner := source.get_default_reader()!
		failure := owner.read_all_bytes_deprecated()
		mut controller := source.default_controller()!
		controller.enqueue(chunk)!
		assert failure.state == .rejected
		assert failure.result.simple_exception_?.type_ == .type_error
		assert failure.result.simple_exception_?.message == 'Chunk data is not Uint8Array'
		assert source.is_readable() && source.locked() && owner.read_requests().len == 0
	}
	mut source := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	mut owner := source.get_default_reader()!
	failure := owner.read_all_bytes_deprecated()
	owner.release_lock()!
	assert failure.state == .rejected
	assert failure.result.simple_exception_?.type_ == .type_error
	assert failure.result.simple_exception_?.message == 'Reader has been released'
}

fn test_source_read_loop_uint8_witness_honors_offsets_detachment_and_oob() {
	for detached in [false, true] {
		mut stream := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
		mut reader := stream.get_default_reader()!
		result := reader.read_all_bytes_deprecated()
		original := webidl.BufferSource.view(.uint8_array, [u8(1), 2, 3, 4], 1, 2)!
		view := webidl.BufferSource{ ...original, detached_: detached }
		stream.enqueue(runtime_value(webidl.buffer_source_value(view)))!
		stream.close()
		assert result.state == .fulfilled
		assert webidl.get_buffer_source_copy(result.result.buffer_value?) == if detached {
			[]u8{}
		} else {
			[u8(2), 3]
		}
	}
	mut stream := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	mut reader := stream.get_default_reader()!
	result := reader.read_all_bytes_deprecated()
	original := webidl.BufferSource.view(.uint8_array, [u8(1)], 0, 1)!
	view := webidl.BufferSource{ ...original, out_of_bounds_: true }
	stream.enqueue(runtime_value(webidl.buffer_source_value(view)))!
	stream.close()
	assert result.state == .fulfilled
	assert webidl.get_buffer_source_copy(result.result.buffer_value?).len == 0
}
