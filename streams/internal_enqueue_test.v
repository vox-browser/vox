module streams

import webidl

fn test_source_internal_stream_enqueue_delivers_empty_uint8_without_public_controller_gate() {
	mut stream := ReadableStream.create_for_internal()
	stream.set_up_with_byte_reading_support_in_realm(StreamRealm.create(81), none, none, 0)
	mut reader := stream.get_default_reader()!
	first := reader.read()
	assert first.state() == .pending
	stream.enqueue(bytes_value([]))!
	assert first.state() == .fulfilled && !first.result().done
	assert first.result().value.kind == .bytes && first.result().value.bytes_.len == 0
	next := reader.read()
	assert next.state() == .pending
	stream.close()
	assert next.state() == .fulfilled && next.result().done
	mut public_source := ReadableStream.create_for_internal()
	public_source.set_up_with_byte_reading_support_in_realm(StreamRealm.create(82), none, none, 0)
	mut controller := public_source.byte_controller()!
	if _ := controller.enqueue([]) {
		assert false
	} else {
		assert err.msg() == 'TypeError: Cannot enqueue chunk with byte length of zero'
	}
}

fn test_source_internal_empty_byte_enqueue_completes_the_actual_pending_read_loop() {
	mut stream := ReadableStream.create_for_internal()
	stream.set_up_with_byte_reading_support_in_realm(StreamRealm.create(83), none, none, 0)
	mut reader := stream.get_default_reader()!
	result := reader.read_all_bytes_deprecated()
	stream.enqueue(bytes_value([]))!
	assert result.state == .pending && reader.read_requests().len == 1
	stream.close()
	assert result.state == .fulfilled
	assert result.result.buffer_value?.kind == .array_buffer
	assert webidl.get_buffer_source_copy(result.result.buffer_value?).len == 0
}

fn test_source_internal_enqueue_uses_the_abstract_closed_stream_gates() {
	for byte_stream in [false, true] {
		mut stream := if byte_stream {
			ReadableStream.create_for_internal()
		} else {
			ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
		}
		if byte_stream {
			stream.set_up_with_byte_reading_support_in_realm(StreamRealm.create(84), none, none, 0)
		}
		stream.close()
		stream.enqueue(bytes_value([u8(1)]))!
		assert stream.is_closed() && stream.queued_chunks() == 0
		mut reader := stream.get_default_reader()!
		assert reader.read().result().done
	}
}
