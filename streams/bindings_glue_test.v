module streams

fn validate_byte_start(receiver Value, controller &ReadableByteStreamController) ! {
	if receiver.text != 'byte source' || controller.stream().realm().id != 11 {
		return error('byte start callback received the wrong binding values')
	}
}

fn reject_byte_pull(_ Value, _ &ReadableByteStreamController) ! {
	return error('pull failed')
}

fn validate_readable_start(receiver Value, controller &ReadableStreamDefaultController) ! {
	if receiver.text != 'source' || controller.stream().realm().id != 11 {
		return error('readable start callback received the wrong binding values')
	}
}

fn validate_readable_pull(receiver Value, controller &ReadableStreamDefaultController) ! {
	validate_readable_start(receiver, controller)!
}

fn validate_writable_start(receiver Value, controller &WritableStreamDefaultController) ! {
	if receiver.text != 'sink' || controller.stream().realm().id != 11 {
		return error('writable start callback received the wrong binding values')
	}
}

fn validate_writable_write(receiver Value, chunk Value, controller &WritableStreamDefaultController) ! {
	validate_writable_start(receiver, controller)!
	if chunk.number != 42 {
		return error('writable callback received the wrong chunk')
	}
}

fn validate_transform_start(receiver Value, controller &TransformStreamDefaultController) ! {
	if receiver.text != 'transformer' || controller.stream().readable().realm().id != 11 {
		return error('transform start callback received the wrong binding values')
	}
}

fn validate_transform(receiver Value, chunk Value, controller &TransformStreamDefaultController) ![]Value {
	validate_transform_start(receiver, controller)!
	return [chunk]
}

fn validate_flush(receiver Value, controller &TransformStreamDefaultController) ![]Value {
	validate_transform_start(receiver, controller)!
	return [string_value('flushed')]
}

fn test_underlying_source_binding_conversion_preserves_callbacks_and_bytes_type() {
	source := underlying_source_from_bindings(BindingsUnderlyingSource{
		type_: .bytes
		auto_allocate_chunk_size: 64
	})
	assert source.type_ == .bytes
	assert source.auto_allocate_chunk_size? == 64
}

fn test_readable_and_writable_callback_adapters_bind_receiver_controller_and_realm() {
	realm := StreamRealm.create(11)
	mut byte_stream := ReadableStream.create(realm, UnderlyingSource{
		type_: .bytes
	}, QueuingStrategy{})!
	byte_controller := byte_stream.byte_controller()!
	invoke_readable_byte_stream_start_algorithm_callback(validate_byte_start, string_value('byte source'), byte_controller)!
	rejected_pull := invoke_readable_byte_stream_pull_algorithm_callback(realm, reject_byte_pull, string_value('byte source'), byte_controller)
	assert rejected_pull.state() == .rejected
	assert rejected_pull.reason() == 'pull failed'
	assert rejected_pull.realm() == realm

	mut readable := ReadableStream.create(realm, UnderlyingSource{}, QueuingStrategy{})!
	readable_controller := readable.default_controller()!
	invoke_readable_stream_start_algorithm_callback(validate_readable_start, string_value('source'), readable_controller)!
	pull := invoke_readable_stream_pull_algorithm_callback(realm, validate_readable_pull, string_value('source'), readable_controller)
	assert pull.state() == .fulfilled
	assert pull.realm() == realm

	mut writable := WritableStream.create(realm, UnderlyingSink{}, QueuingStrategy{})!
	writable_controller := writable.controller()
	invoke_writable_stream_start_algorithm_callback(validate_writable_start, string_value('sink'), writable_controller)!
	write := invoke_writable_stream_write_algorithm_callback(realm, validate_writable_write, string_value('sink'), number_value(42), writable_controller)
	assert write.state() == .fulfilled
	assert write.realm() == realm
}

fn test_transform_callback_adapters_preserve_receiver_controller_and_results() {
	realm := StreamRealm.create(11)
	mut transform := TransformStream.create(realm, Transformer{}, QueuingStrategy{}, QueuingStrategy{})!
	controller := transform.controller()
	invoke_transform_stream_start_algorithm_callback(validate_transform_start, string_value('transformer'), controller)!
	outputs := invoke_transform_stream_transform_algorithm_callback(validate_transform, string_value('transformer'), number_value(9), controller)!
	assert outputs.len == 1
	assert outputs[0].number == 9
	flushed := invoke_transform_stream_flush_algorithm_callback(validate_flush, string_value('transformer'), controller)!
	assert flushed.len == 1
	assert flushed[0].text == 'flushed'
}
