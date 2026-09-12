module streams

fn test_stream_factories_preserve_realm_and_prepare_wrappers() {
	realm := StreamRealm.create(42)
	mut readable := ReadableStream.create_for_constructor(realm, UnderlyingSource{}, QueuingStrategy{})!
	assert readable.realm() == realm

	result_realm := StreamRealm.create(84)
	readable.set_result_realm(result_realm)
	assert readable.result_realm()? == result_realm

	mut reader := ReadableStreamDefaultReader.create(realm, mut readable)!
	assert reader.closed_promise_realm() == realm
	assert reader.closed().realm() == realm
	readable.enqueue(string_value('realm-bound'))!
	read := reader.read()
	assert read.realm() == realm
	assert read.result_realm()? == result_realm

	mut writable := WritableStream.create_for_constructor(realm, UnderlyingSink{}, QueuingStrategy{})!
	assert writable.realm() == realm
	mut writer := WritableStreamDefaultWriter.create(realm, mut writable)!
	assert writer.closed_promise_realm() == realm
	assert writer.ready_promise_realm() == realm
	assert writer.write(number_value(1)).realm() == realm
	assert writer.close().realm() == realm

	transform := TransformStream.create_for_constructor(realm, Transformer{}, QueuingStrategy{}, QueuingStrategy{})!
	assert transform.readable().realm() == realm
	assert transform.writable().realm() == realm
	assert transform.wrappers_are_prepared()
	assert transform.backpressure_change_promise_realm() == realm
	assert TransformStream.readable_offset() == 0
	assert TransformStream.writable_offset() == 1
}

fn test_readable_values_sets_async_iterator_prototype() {
	mut readable := ReadableStream.from_in_realm(StreamRealm.create(7), [number_value(1)])!
	iterator := readable.values(ReadableStreamIteratorOptions{})!
	assert iterator.prototype_is_set()
}

fn test_constructor_factories_reject_reserved_type_members() {
	realm := StreamRealm.create(1)
	if _ := WritableStream.create_for_constructor(realm, UnderlyingSink{
		type_: 'reserved'
	}, QueuingStrategy{}) {
		assert false
	} else {
		assert err.msg().contains("reserved key 'type'")
	}

	if _ := TransformStream.create_for_constructor(realm, Transformer{
		readable_type: 'reserved'
	}, QueuingStrategy{}, QueuingStrategy{}) {
		assert false
	} else {
		assert err.msg().contains("reserved key 'readableType'")
	}
}
