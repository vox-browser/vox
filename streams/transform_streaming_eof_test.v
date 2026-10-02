module streams

@[heap]
struct StreamingTransformObservation {
mut:
	flushed bool
	chunks []string
	ended bool
}

fn continue_streaming_transform_read(reader &ReadableStreamDefaultReader, state &StreamingTransformObservation) {
	mut mutable_reader := unsafe { &ReadableStreamDefaultReader(reader) }
	mut result := mutable_reader.read()
	result.upon_settlement(fn [reader, state] (read ReadResult) {
		mut observation := unsafe { &StreamingTransformObservation(state) }
		if read.done { observation.ended = true; return }
		observation.chunks << read.value.bytes_.bytestr()
		continue_streaming_transform_read(reader, state)
	}, fn (_ string) { assert false })
}

fn test_identity_transform_keeps_a_waiting_read_ahead_of_zero_high_water_mark_backpressure() {
	state := &StreamingTransformObservation{}
	mut source := ReadableStream.construct_impl(UnderlyingSource{ type_: .bytes }, QueuingStrategy{})!
	mut transform := TransformStream.construct_impl(Transformer{}, QueuingStrategy{}, QueuingStrategy{})!
	mut readable := source.piped_through(mut transform, false, false, false, none)
	reader := readable.get_default_reader()!
	continue_streaming_transform_read(reader, state)
	source.enqueue(bytes_value('first'.bytes()))!
	source.enqueue(bytes_value('second'.bytes()))!
	assert state.chunks == ['first', 'second']
	source.close()
	assert state.ended
}

fn test_transform_close_flushes_while_its_readable_side_has_zero_capacity() {
	state := &StreamingTransformObservation{}
	transform := TransformStream.construct_impl(Transformer{
		flush: fn [state] () ![]Value {
			mut observation := unsafe { &StreamingTransformObservation(state) }
			observation.flushed = true
			return []Value{}
		}
	}, QueuingStrategy{}, QueuingStrategy{})!
	assert transform.backpressure()
	mut writable := transform.writable()
	closed := writable.close()
	assert closed.state() == .fulfilled
	assert state.flushed
	assert transform.readable().state() == .closed
}

fn test_identity_transform_restarts_pull_for_each_future_chunk_and_flushes_at_eof() {
	state := &StreamingTransformObservation{}
	mut source := ReadableStream.construct_impl(UnderlyingSource{ type_: .bytes }, QueuingStrategy{})!
	mut transform := TransformStream.construct_impl(Transformer{
		flush: fn [state] () ![]Value {
			mut observation := unsafe { &StreamingTransformObservation(state) }
			observation.flushed = true
			return []Value{}
		}
	}, QueuingStrategy{}, QueuingStrategy{})!
	mut readable := source.piped_through(mut transform, false, false, false, none)
	mut reader := readable.get_default_reader()!
	first := reader.read()
	assert first.state() == .pending
	source.enqueue(bytes_value('first'.bytes()))!
	assert first.state() == .fulfilled
	assert first.result().value.bytes_ == 'first'.bytes()
	second := reader.read()
	assert second.state() == .pending
	source.enqueue(bytes_value('second'.bytes()))!
	assert second.state() == .fulfilled
	assert second.result().value.bytes_ == 'second'.bytes()
	end := reader.read()
	source.close()
	assert end.state() == .fulfilled
	assert end.result().done
	assert state.flushed
}
