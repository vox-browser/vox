module html

import dom

fn test_resizable_array_buffer_clones_preserve_capacity_and_copy_bytes() {
	for for_storage in [false, true] {
		mut buffer := StructuredObject.create(.array_buffer)
		buffer.bytes = [u8(10), 20, 30]
		buffer.max_byte_length = 12
		value := structured_object_value(buffer)
		record := if for_storage {
			structured_serialize_for_storage(value)!
		} else {
			structured_serialize(value)!
		}
		assert record.data[if for_storage { 6 } else { 0 }] == u8(StructuredSerializeValueTag.resizable_array_buffer)
		mut cloned := structured_object_from_value(structured_deserialize(record)!)!
		assert cloned.kind == .array_buffer
		assert cloned.max_byte_length? == 12
		assert cloned.bytes == [u8(10), 20, 30]
		buffer.overwrite_array_buffer(0, [u8(40)])!
		assert cloned.bytes == [u8(10), 20, 30]
		cloned.overwrite_array_buffer(1, [u8(50)])!
		assert buffer.bytes == [u8(40), 20, 30]
	}
}

fn test_resizable_array_buffer_view_keeps_tracking_lengths_and_buffer_identity() {
	mut buffer := StructuredObject.create(.array_buffer)
	buffer.bytes = [u8(1), 2, 3, 4]
	buffer.max_byte_length = 16
	mut view := StructuredObject.create(.array_buffer_view)
	view.viewed_array_buffer = buffer
	view.string_data = 'Uint8Array'
	view.byte_offset = 1
	mut root := StructuredObject.create(.array)
	view_value := structured_object_value(view)
	buffer_value := structured_object_value(buffer)
	root.values = [&view_value, &buffer_value]
	decoded :=
		structured_object_from_value(structured_deserialize(structured_serialize(structured_object_value(root))!)!)!
	decoded_view := structured_object_from_value(*decoded.values[0])!
	decoded_buffer := structured_object_from_value(*decoded.values[1])!
	assert decoded_view.byte_length == none
	assert decoded_view.array_length == none
	assert decoded_view.byte_offset == 1
	assert decoded_view.viewed_array_buffer? == decoded_buffer
	assert decoded_buffer.max_byte_length? == 16
}

fn test_empty_resizable_array_buffer_stays_distinct_from_fixed_buffer() {
	mut resizable := StructuredObject.create(.array_buffer)
	resizable.max_byte_length = 0
	cloned_resizable :=
		structured_object_from_value(structured_deserialize(structured_serialize(structured_object_value(resizable))!)!)!
	assert cloned_resizable.max_byte_length? == 0
	fixed := StructuredObject.create(.array_buffer)
	record := structured_serialize(structured_object_value(fixed))!
	assert record.data[0] == u8(StructuredSerializeValueTag.array_buffer)
	cloned_fixed := structured_object_from_value(structured_deserialize(record)!)!
	assert cloned_fixed.max_byte_length == none
}

fn test_resizable_array_buffer_rejects_inconsistent_maximum_and_truncated_record() {
	mut invalid := StructuredObject.create(.array_buffer)
	invalid.bytes = [u8(1), 2]
	invalid.max_byte_length = 1
	mut rejected := false
	structured_serialize(structured_object_value(invalid)) or {
		assert err.msg().contains('maximum length')
		rejected = true
		SerializationRecord{}
	}
	assert rejected
	invalid.max_byte_length = 2
	record := structured_serialize(structured_object_value(invalid))!
	for data in [record.data[..record.data.len - 1],
		[u8(StructuredSerializeValueTag.resizable_array_buffer), 2, 0, 0, 0, 1, 2, 1, 0, 0, 0]] {
		rejected = false
		structured_deserialize(SerializationRecord{ data: data }) or {
			assert err.msg().contains('DataCloneError')
			rejected = true
			dom.js_undefined()
		}
		assert rejected
	}
}
