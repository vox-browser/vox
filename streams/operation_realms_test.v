module streams

fn test_stream_operation_records_derive_execution_realm_from_their_promise() {
	realm := StreamRealm.create(55)
	promise := VoidPromise.pending_in(realm)
	assert promise_realm(promise) == realm
	assert ReadableStreamGenericReaderMixin.from_promise(promise).closed_promise_realm() == realm
	assert ReadableStreamPipeTo.from_promise(promise).promise_realm() == realm
	assert ReadableStreamTeeReadRequest.from_promise(promise).promise_realm() == realm
	assert ReadableByteStreamTeeDefaultReadRequest.from_promise(promise).promise_realm() == realm
	assert ReadableByteStreamTeeBYOBReadRequest.from_promise(promise).promise_realm() == realm
}

fn test_pipe_operation_uses_source_realm_while_waiting_for_input() {
	realm := StreamRealm.create(91)
	mut source := ReadableStream.create(realm, UnderlyingSource{}, QueuingStrategy{})!
	mut destination := WritableStream.create(StreamRealm.create(92), UnderlyingSink{}, QueuingStrategy{})!
	pipe := source.pipe_to(mut destination, StreamPipeOptions{})
	assert pipe.state() == .pending
	assert !isnil(source.pipe_operation_)
	assert source.pipe_operation_.promise_realm() == realm
	assert source.default_reader_.pipe_to_operation_ == source.pipe_operation_
}

fn test_writable_controller_signal_wrapper_slot_is_stable() {
	assert WritableStreamDefaultController.signal_offset() == 0
}
