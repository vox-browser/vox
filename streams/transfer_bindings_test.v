module streams

fn test_stream_object_binding_casts_only_accept_the_matching_wrapper() {
	readable := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	writable := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	readable_object := StreamObject.from_readable(readable)
	writable_object := StreamObject.from_writable(writable)
	assert readable_stream_from_object(readable_object)! == readable
	assert writable_stream_from_object(writable_object)! == writable
	if _ := readable_stream_from_object(writable_object) {
		assert false
	} else {
		assert err.msg().contains('ReadableStream')
	}
	if _ := writable_stream_from_object(readable_object) {
		assert false
	} else {
		assert err.msg().contains('WritableStream')
	}
}

fn test_readable_stream_serialization_locks_source_and_uses_receiving_realm() {
	mut source := ReadableStream.from_in_realm(StreamRealm.create(1), [string_value('transferred')])!
	mut encoder := TransferDataEncoder{}
	serialize_readable_stream_with_transfer(source.realm(), mut encoder, mut source)!
	assert source.locked()
	assert encoder.record_count() == 1

	mut decoder := encoder.decoder()
	receiving_realm := StreamRealm.create(2)
	mut received := ReadableStream{}
	received.transfer_receiving_steps_from(receiving_realm, mut decoder)!
	assert received.realm() == receiving_realm
	mut reader := received.get_default_reader()!
	read := reader.read()
	assert read.result().value.text == 'transferred'
	assert read.realm() == receiving_realm
}

fn test_writable_stream_serialization_forwards_writes_in_receiving_realm() {
	mut destination := WritableStream.create(StreamRealm.create(3), UnderlyingSink{}, QueuingStrategy{})!
	mut encoder := TransferDataEncoder{}
	serialize_writable_stream_with_transfer(destination.realm(), mut encoder, mut destination)!
	assert destination.locked()
	assert encoder.record_count() == 1

	mut decoder := encoder.decoder()
	receiving_realm := StreamRealm.create(4)
	mut received := WritableStream{}
	received.transfer_receiving_steps_from(receiving_realm, mut decoder)!
	mut writer := received.get_writer()!
	write := writer.write(string_value('forwarded'))
	assert write.state() == .fulfilled
	assert write.realm() == receiving_realm
	assert destination.written_values()[0].text == 'forwarded'
}

fn test_transfer_decoder_rejects_a_mismatched_stream_type() {
	mut readable := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	mut encoder := TransferDataEncoder{}
	serialize_readable_stream_with_transfer(readable.realm(), mut encoder, mut readable)!
	mut decoder := encoder.decoder()
	mut writable := WritableStream{}
	if _ := writable.transfer_receiving_steps_from(StreamRealm.create(9), mut decoder) {
		assert false
	} else {
		assert err.msg().contains('does not match')
	}
}
