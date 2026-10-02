module html

import dom
import math

fn test_structured_serialize_primitives() {
	values := [
		dom.js_undefined(),
		dom.js_null(),
		dom.js_bool(true),
		dom.js_number(-12.5),
		dom.js_string('Ladybird 🐞'),
	]
	for value in values {
		record := structured_serialize(value) or { panic(err) }
		decoded := structured_deserialize(record) or { panic(err) }
		assert decoded.kind == value.kind
		assert decoded.boolean_data == value.boolean_data
		if value.kind == .number {
			assert math.f64_bits(decoded.number_data) == math.f64_bits(value.number_data)
		}
		assert decoded.string_data == value.string_data
	}
}

fn test_structured_serialize_preserves_aliases_and_cycles() {
	mut shared_object := StructuredObject.create(.object)
	shared_text := &dom.JSValue{
		kind: .string
		string_data: 'shared'
	}
	shared_object.properties << StructuredProperty{
		key: 'name'
		value: shared_text
	}
	shared_value := &dom.JSValue{
		kind: .object
		object_data: voidptr(shared_object)
		is_structured_object_: true
	}

	mut root := StructuredObject.create(.array)
	root_value := &dom.JSValue{
		kind: .object
		object_data: voidptr(root)
		is_structured_object_: true
	}
	root.values << shared_value
	root.values << shared_value
	root.values << root_value

	record := structured_serialize(*root_value) or { panic(err) }
	decoded := structured_deserialize(record) or { panic(err) }
	decoded_root := structured_object_from_value(decoded) or { panic(err) }
	assert decoded_root.kind == .array
	assert decoded_root.values.len == 3
	assert decoded_root.values[0].object_data == decoded_root.values[1].object_data
	assert decoded_root.values[2].object_data == decoded.object_data
	decoded_shared := structured_object_from_value(*decoded_root.values[0]) or { panic(err) }
	assert decoded_shared.properties[0].key == 'name'
	assert decoded_shared.properties[0].value.string_data == 'shared'
}

fn test_structured_serialize_composite_types() {
	key := &dom.JSValue{
		kind: .string
		string_data: 'buffer'
	}
	mut buffer := StructuredObject.create(.array_buffer)
	buffer.bytes = [u8(1), 2, 3, 255]
	buffer_value := &dom.JSValue{
		kind: .object
		object_data: voidptr(buffer)
		is_structured_object_: true
	}
	mut map_object := StructuredObject.create(.map)
	map_object.entries << StructuredMapEntry{
		key: key
		value: buffer_value
	}
	map_value := structured_object_value(map_object)

	decoded := structured_deserialize(structured_serialize_for_storage(map_value) or { panic(err) }) or {
		panic(err)
	}
	decoded_map := structured_object_from_value(decoded) or { panic(err) }
	assert decoded_map.kind == .map
	assert decoded_map.entries.len == 1
	assert decoded_map.entries[0].key.string_data == 'buffer'
	decoded_buffer := structured_object_from_value(*decoded_map.entries[0].value) or { panic(err) }
	assert decoded_buffer.bytes == [u8(1), 2, 3, 255]
}

fn test_structured_serialize_array_buffer_view_and_error_names() {
	mut buffer := StructuredObject.create(.array_buffer)
	buffer.bytes = [u8(10), 20, 30, 40]
	mut view := StructuredObject.create(.array_buffer_view)
	view.viewed_array_buffer = buffer
	view.string_data = 'Uint16Array'
	view.byte_length = 2
	view.byte_offset = 2
	view.array_length = 1
	decoded_value := structured_deserialize(structured_serialize(structured_object_value(view))!)!
	decoded := structured_object_from_value(decoded_value)!
	assert decoded.kind == .array_buffer_view
	assert decoded.string_data == 'Uint16Array'
	assert decoded.byte_length? == 2
	assert decoded.byte_offset == 2
	assert decoded.array_length? == 1
	assert decoded.viewed_array_buffer?.bytes == [u8(10), 20, 30, 40]
	assert error_name_to_type('TypeError') == .type_error
	assert error_name_to_type('SomethingElse') == .error
}

fn test_structured_deserialize_rejects_bad_records() {
	structured_deserialize(SerializationRecord{}) or {
		assert err.msg().contains('empty')
		return
	}
	assert false
}

fn test_structured_deserialize_rejects_trailing_data() {
	structured_deserialize(SerializationRecord{
		data: [u8(StructuredSerializeValueTag.null_primitive), 99]
	}) or {
		assert err.msg().contains('trailing')
		return
	}
	assert false
}

fn test_structured_serialize_rejects_unrecognized_host_objects() {
	structured_serialize(dom.js_object(voidptr(1))) or {
		assert err.msg().contains('DataCloneError')
		return
	}
	assert false
}

fn test_structured_serialize_shared_array_buffer_aliases_same_process_clones() {
	mut source := StructuredObject.create_shared_array_buffer('shared array buffer'.bytes(), none)
	record := structured_serialize_with_shared_array_buffers(structured_object_value(source), .same_agent_always)!
	assert record.shared_array_buffers.len == 1
	assert voidptr(record.shared_array_buffers[0]) == voidptr(source)

	decoded_value := structured_deserialize(record)!
	mut clone := structured_object_from_value(decoded_value)!
	assert voidptr(clone) != voidptr(source)
	assert clone.kind == .shared_array_buffer
	assert clone.array_buffer_bytes() == 'shared array buffer'.bytes()
	source_store := source.shared_backing_store or { panic('missing source backing store') }
	clone_store := clone.shared_backing_store or { panic('missing clone backing store') }
	assert voidptr(clone_store) == voidptr(source_store)

	source.overwrite_array_buffer(0, 'S'.bytes())!
	assert clone.array_buffer_bytes()[0] == `S`
	clone.overwrite_array_buffer(1, 'C'.bytes())!
	assert source.array_buffer_bytes()[1] == `C`
}

fn test_structured_serialize_shared_array_buffer_flattens_alias_chains() {
	source := StructuredObject.create_shared_array_buffer('flatten me'.bytes(), none)
	first_record := structured_serialize_with_shared_array_buffers(structured_object_value(source), .same_agent_always)!
	first_clone_value := structured_deserialize(first_record)!
	first_clone := structured_object_from_value(first_clone_value)!
	second_record := structured_serialize_with_shared_array_buffers(first_clone_value, .same_agent_always)!
	second_clone := structured_object_from_value(structured_deserialize(second_record)!)!

	source_store := source.shared_backing_store or { panic('missing source backing store') }
	first_store := first_clone.shared_backing_store or { panic('missing first clone backing store') }
	second_store := second_clone.shared_backing_store or { panic('missing second clone backing store') }
	assert voidptr(first_store) == voidptr(source_store)
	assert voidptr(second_store) == voidptr(source_store)
}

fn test_structured_serialize_shared_array_buffer_through_view_aliases() {
	source := StructuredObject.create_shared_array_buffer('viewed buffer'.bytes(), none)
	mut view := StructuredObject.create(.array_buffer_view)
	view.viewed_array_buffer = source
	view.string_data = 'Uint8Array'
	view.byte_length = u32(source.array_buffer_bytes().len)
	view.array_length = u32(source.array_buffer_bytes().len)

	record := structured_serialize_with_shared_array_buffers(structured_object_value(view), .same_agent_always)!
	clone := structured_object_from_value(structured_deserialize(record)!)!
	cloned_buffer := clone.viewed_array_buffer or { panic('missing viewed buffer') }
	assert cloned_buffer.kind == .shared_array_buffer
	source_store := source.shared_backing_store or { panic('missing source backing store') }
	clone_store := cloned_buffer.shared_backing_store or { panic('missing clone backing store') }
	assert voidptr(clone_store) == voidptr(source_store)
}

fn test_structured_serialize_shared_array_buffer_cross_process_falls_back_to_copy() {
	mut source := StructuredObject.create_shared_array_buffer('copied across processes'.bytes(), none)
	record := structured_serialize_with_shared_array_buffers(structured_object_value(source), .same_agent_always)!
	cross_process_record := SerializationRecord{
		data: record.data.clone()
	}
	mut clone := structured_object_from_value(structured_deserialize(cross_process_record)!)!
	assert clone.kind == .shared_array_buffer
	source_store := source.shared_backing_store or { panic('missing source backing store') }
	clone_store := clone.shared_backing_store or { panic('missing clone backing store') }
	assert voidptr(clone_store) != voidptr(source_store)
	assert clone.array_buffer_bytes() == source.array_buffer_bytes()

	source.overwrite_array_buffer(0, 'X'.bytes())!
	assert clone.array_buffer_bytes()[0] != `X`
}

fn test_structured_serialize_growable_shared_array_buffer_preserves_maximum() {
	mut source := StructuredObject.create_shared_array_buffer('growable'.bytes(), u64(128))
	record := structured_serialize_with_shared_array_buffers(structured_object_value(source), .same_agent_always)!
	clone := structured_object_from_value(structured_deserialize(record)!)!
	assert clone.max_byte_length? == 128
	source_store := source.shared_backing_store or { panic('missing source backing store') }
	clone_store := clone.shared_backing_store or { panic('missing clone backing store') }
	assert voidptr(clone_store) == voidptr(source_store)
	source.grow_shared_array_buffer(16)!
	assert clone.array_buffer_bytes().len == 16
}

fn test_structured_serialize_zero_length_shared_array_buffer_round_trips() {
	source := StructuredObject.create_shared_array_buffer([], none)
	record := structured_serialize_with_shared_array_buffers(structured_object_value(source), .same_agent_always)!
	clone := structured_object_from_value(structured_deserialize(record)!)!
	assert clone.kind == .shared_array_buffer
	assert clone.array_buffer_bytes().len == 0
}

fn test_structured_serialize_shared_array_buffer_gates_and_storage() {
	source := StructuredObject.create_shared_array_buffer('gated'.bytes(), none)
	structured_serialize(structured_object_value(source)) or {
		assert err.msg().contains('cross-origin isolated')
		structured_serialize_for_storage_with_shared_array_buffers(structured_object_value(source), .same_agent_always) or {
			assert err.msg().contains('for storage')
			return
		}
	}
	assert false
}
