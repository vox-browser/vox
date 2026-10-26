module html

import dom

fn test_transfer_memory_uses_list_order_and_omits_transferred_buffer_payloads() {
	mut first := StructuredObject.create(.array_buffer)
	first.bytes = [u8(1), 2, 3]
	mut second := StructuredObject.create(.array_buffer)
	second.bytes = [u8(4), 5]
	for index, source in [second, first] {
		record := structured_serialize_with_transfer_memory(structured_object_value(source), [
			second,
			first,
		])!
		assert record.data == [u8(18), u8(index), 0, 0, 0]
		mut received_first := StructuredObject.create(.array_buffer)
		received_first.bytes = [u8(11), 12, 13]
		mut received_second := StructuredObject.create(.array_buffer)
		received_second.bytes = [u8(14), 15]
		objects := [received_second, received_first]
		decoded := structured_deserialize_with_transfer_memory(record, objects, StructuredDeserializationContext{})!
		assert decoded.object_data == voidptr(objects[index])
		assert decoded.object_data != voidptr(source)
	}
}

fn test_transfer_memory_preserves_graph_cycles_views_and_following_object_indices() {
	mut buffer := StructuredObject.create(.array_buffer)
	buffer.bytes = [u8(1), 2, 3, 4]
	unused := StructuredObject.create(.array_buffer)
	mut view := StructuredObject.create(.array_buffer_view)
	view.viewed_array_buffer = buffer
	view.string_data = 'Uint8Array'
	view.byte_offset = 1
	view.byte_length = 2
	view.array_length = 2
	mut root := StructuredObject.create(.array)
	root_value := structured_object_value(root)
	view_value := structured_object_value(view)
	buffer_value := structured_object_value(buffer)
	root.values = [&view_value, &buffer_value, &view_value, &root_value]
	record := structured_serialize_with_transfer_memory(root_value, [unused, buffer])!
	mut received := StructuredObject.create(.array_buffer)
	received.bytes = [u8(5), 6, 7, 8]
	decoded := structured_object_from_value(structured_deserialize_with_transfer_memory(record,
		[StructuredObject.create(.array_buffer), received], StructuredDeserializationContext{})!)!
	assert decoded.values.len == 4
	assert decoded.values[0].object_data == decoded.values[2].object_data
	assert decoded.values[1].object_data == voidptr(received)
	assert decoded.values[3].object_data == voidptr(decoded)
	decoded_view := structured_object_from_value(*decoded.values[0])!
	assert voidptr(decoded_view.viewed_array_buffer?) == voidptr(received)
	assert decoded_view.byte_offset == 1
	assert decoded_view.byte_length? == 2
	assert decoded_view.array_length? == 2
	assert decoded_view.viewed_array_buffer?.bytes == [u8(5), 6, 7, 8]
}

fn test_transfer_memory_keeps_resizable_view_slots_and_checks_receiving_bounds() {
	mut buffer := StructuredObject.create(.array_buffer)
	buffer.bytes = [u8(1), 2, 3, 4]
	buffer.max_byte_length = 8
	mut view := StructuredObject.create(.array_buffer_view)
	view.viewed_array_buffer = buffer
	view.string_data = 'DataView'
	view.byte_offset = 2
	record := structured_serialize_with_transfer_memory(structured_object_value(view), [buffer])!
	mut received := StructuredObject.create(.array_buffer)
	received.bytes = [u8(5), 6, 7]
	received.max_byte_length = 8
	decoded := structured_object_from_value(structured_deserialize_with_transfer_memory(record,
		[received], StructuredDeserializationContext{})!)!
	assert decoded.byte_length == none
	assert decoded.array_length == none
	assert decoded.byte_offset == 2
	assert voidptr(decoded.viewed_array_buffer?) == voidptr(received)
	received.bytes = [u8(1)]
	if _ := structured_deserialize_with_transfer_memory(record, [received], StructuredDeserializationContext{}) {
		assert false, 'received view must fit the transferred buffer'
	} else {
		assert err.msg().contains('DataCloneError')
	}
}

fn test_transfer_memory_rejects_invalid_seeds_references_and_storage_records() {
	buffer := StructuredObject.create(.array_buffer)
	value := structured_object_value(buffer)
	for memory in [[buffer, buffer], [unsafe { &StructuredObject(nil) }]] {
		if _ := structured_serialize_with_transfer_memory(value, memory) {
			assert false
		} else {
			assert err.msg().contains('DataCloneError')
		}
		if _ := structured_deserialize_with_transfer_memory(SerializationRecord{ data: [
			u8(18),
			0,
			0,
			0,
			0,
		] }, memory, StructuredDeserializationContext{}) {
			assert false
		} else {
			assert err.msg().contains('DataCloneError')
		}
	}
	for data in [[]u8{}, [u8(18), 1, 0, 0, 0], [u8(18), 0]] {
		if _ := structured_deserialize_with_transfer_memory(SerializationRecord{ data: data }, [buffer], StructuredDeserializationContext{}) {
			assert false
		} else {
			assert err.msg().contains('DataCloneError')
		}
	}
	stored := structured_serialize_for_storage(dom.js_null())!
	if _ := structured_deserialize_with_transfer_memory(stored, [buffer], StructuredDeserializationContext{}) {
		assert false
	} else {
		assert err.msg().contains('IPC')
	}
	// Empty seeded memories retain existing IPC bytes and its trailing-byte rule.
	plain := structured_serialize(value)!
	assert structured_serialize_with_transfer_memory(value, [])!.data == plain.data
	mut number_bytes := structured_serialize(dom.js_number(42))!.data.clone()
	number_bytes << u8(255)
	assert structured_deserialize_with_transfer_memory(SerializationRecord{ data: number_bytes }, [], StructuredDeserializationContext{})!.number_data == 42
}
