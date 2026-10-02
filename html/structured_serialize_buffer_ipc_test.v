module html

fn test_source_ipc_buffer_capacity_keeps_u64_width_and_shared_side_table() {
	mut buffer := StructuredObject.create(.array_buffer)
	buffer.bytes = [u8(170)]
	buffer.max_byte_length = u64(4294967313)
	record := structured_serialize(structured_object_value(buffer))!
	assert record.data == [u8(21), 1, 0, 0, 0, 170, 17, 0, 0, 0, 1, 0, 0, 0]
	decoded := structured_object_from_value(structured_deserialize(record)!)!
	assert decoded.max_byte_length? == u64(4294967313)
	shared_buffer := StructuredObject.create_shared_array_buffer([u8(170)], u64(4294967313))
	shared_record := structured_serialize_with_shared_array_buffers(structured_object_value(shared_buffer), .same_agent_always)!
	assert shared_record.data == [u8(19), 0, 0, 0, 0, 1, 0, 0, 0, 170, 17, 0, 0, 0, 1, 0, 0, 0]
	shared_decoded := structured_object_from_value(structured_deserialize(shared_record)!)!
	assert shared_decoded.max_byte_length? == u64(4294967313)
	assert voidptr(shared_decoded.shared_backing_store?) == voidptr(shared_buffer.shared_backing_store?)
}

fn test_source_ipc_data_view_has_no_array_length_and_buffer_precedes_view_memory_id() {
	mut buffer := StructuredObject.create(.array_buffer)
	buffer.bytes = [u8(1), 2, 3, 4]
	mut view := StructuredObject.create(.array_buffer_view)
	view.viewed_array_buffer = buffer
	view.string_data = 'DataView'
	view.byte_length = 2
	view.byte_offset = 1
	view_record := structured_serialize(structured_object_value(view))!
	view_golden := [u8(23), 22, 4, 0, 0, 0, 1, 2, 3, 4,
		1, 8, 0, 0, 0, 68, 97, 116, 97, 86, 105, 101, 119,
		0, 2, 0, 0, 0, 1, 0, 0, 0]
	assert view_record.data == view_golden
	decoded_view := structured_object_from_value(structured_deserialize(view_record)!)!
	assert decoded_view.byte_length? == 2
	assert decoded_view.array_length == none
	mut root := StructuredObject.create(.array)
	view_value := structured_object_value(view)
	buffer_value := structured_object_value(buffer)
	root.values = [&view_value, &buffer_value, &view_value]
	mut expected := [u8(15), 3, 0, 0, 0, 0, 0, 0, 0]
	expected << view_golden
	expected << [u8(1), 1, 0, 0, 0, 48, 18, 1, 0, 0, 0, 1, 1, 0, 0, 0, 49,
		18, 2, 0, 0, 0, 1, 1, 0, 0, 0, 50, 255]
	record := structured_serialize(structured_object_value(root))!
	assert record.data == expected
	decoded := structured_object_from_value(structured_deserialize(record)!)!
	first_view := structured_object_from_value(*decoded.values[0])!
	assert voidptr(first_view.viewed_array_buffer?) == decoded.values[1].object_data
	assert decoded.values[0].object_data == decoded.values[2].object_data
}

fn test_source_ipc_auto_view_lengths_use_true_flags_and_source_typed_slot_validation() {
	mut buffer := StructuredObject.create(.array_buffer)
	buffer.bytes = [u8(1), 2]
	buffer.max_byte_length = 6
	mut view := StructuredObject.create(.array_buffer_view)
	view.viewed_array_buffer = buffer
	view.string_data = 'Uint8Array'
	view.byte_offset = 1
	record := structured_serialize(structured_object_value(view))!
	assert record.data == [u8(23), 21, 2, 0, 0, 0, 1, 2, 6, 0, 0, 0, 0, 0, 0, 0,
		1, 10, 0, 0, 0, 85, 105, 110, 116, 56, 65, 114, 114, 97, 121, 1, 1, 0, 0, 0, 1]
	decoded := structured_object_from_value(structured_deserialize(record)!)!
	assert decoded.byte_length == none && decoded.array_length == none
	for constructor_name in ['Uint8Array', 'Uint8ClampedArray', 'Int8Array', 'Uint16Array',
		'Int16Array', 'Float16Array', 'Uint32Array', 'Int32Array', 'Float32Array',
		'BigUint64Array', 'BigInt64Array', 'Float64Array'] {
		view.string_data = constructor_name
		view.byte_offset = 0
		view.byte_length = 0
		view.array_length = 0
		assert structured_object_from_value(structured_deserialize(structured_serialize(structured_object_value(view))!)!)!.string_data == constructor_name
	}
}

fn test_source_ipc_view_decoder_rejects_invalid_brands_alignment_lengths_and_bounds() {
	// Fixed 4-byte buffer, Uint16Array(1 element), offset 2: a valid source view.
	valid := [u8(23), 22, 4, 0, 0, 0, 1, 2, 3, 4, 1, 11, 0, 0, 0,
		85, 105, 110, 116, 49, 54, 65, 114, 114, 97, 121,
		0, 2, 0, 0, 0, 2, 0, 0, 0, 0, 1, 0, 0, 0]
	assert structured_object_from_value(structured_deserialize(SerializationRecord{data: valid})!)!.byte_offset == 2
	mut unknown := valid.clone()
	unknown[15] = 88
	mut misaligned := valid.clone()
	misaligned[31] = 1
	mut inconsistent := valid.clone()
	inconsistent[27] = 1
	mut exceeds_buffer := valid.clone()
	exceeds_buffer[31] = 4
	mut auto_fixed := valid[..26].clone()
	auto_fixed << [u8(1), 0, 0, 0, 0, 1]
	for data in [unknown, misaligned, inconsistent, exceeds_buffer, auto_fixed] {
		if _ := structured_deserialize(SerializationRecord{data: data}) { assert false } else { assert err.msg().contains('DataCloneError') }
	}
}
