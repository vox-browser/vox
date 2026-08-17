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
		kind:        .string
		string_data: 'shared'
	}
	shared_object.properties << StructuredProperty{
		key:   'name'
		value: shared_text
	}
	shared_value := &dom.JSValue{
		kind:                  .object
		object_data:           voidptr(shared_object)
		is_structured_object_: true
	}

	mut root := StructuredObject.create(.array)
	root_value := &dom.JSValue{
		kind:                  .object
		object_data:           voidptr(root)
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
		kind:        .string
		string_data: 'buffer'
	}
	mut buffer := StructuredObject.create(.array_buffer)
	buffer.bytes = [u8(1), 2, 3, 255]
	buffer_value := &dom.JSValue{
		kind:                  .object
		object_data:           voidptr(buffer)
		is_structured_object_: true
	}
	mut map_object := StructuredObject.create(.map)
	map_object.entries << StructuredMapEntry{
		key:   key
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
