module html

import dom
import libjs

fn test_source_ipc_object_array_map_and_set_collection_framing_goldens() {
	mut object := StructuredObject.create(.object)
	item := dom.js_null()
	object.properties = [StructuredProperty{key: 'x', value: &item}]
	assert structured_serialize(structured_object_value(object))!.data == [u8(17), 2, 1, 1, 0, 0, 0, 120, 255]
	mut array := StructuredObject.create(.array)
	array.values = [&item]
	assert structured_serialize(structured_object_value(array))!.data == [u8(15), 1, 0, 0, 0, 0, 0, 0, 0, 2, 1, 1, 0, 0, 0, 48, 255]
	mut map_object := StructuredObject.create(.map)
	key := dom.js_bool(true)
	map_object.entries = [StructuredMapEntry{key: &key, value: &item}]
	assert structured_serialize(structured_object_value(map_object))!.data == [u8(13), 1, 0, 0, 0, 0, 0, 0, 0, 3, 1, 2]
	mut set := StructuredObject.create(.set)
	set.values = [&item]
	assert structured_serialize(structured_object_value(set))!.data == [u8(14), 1, 0, 0, 0, 0, 0, 0, 0, 2]
}

fn test_source_ipc_sparse_array_retains_length_property_units_aliases_and_cycles() {
	mut array := StructuredObject.create(.array)
	array.array_length = u32(-1)
	mut object := StructuredObject.create(.object)
	object_value := structured_object_value(object)
	array_value := structured_object_value(array)
	lone_key := libjs.utf16_string_from_code_units([u16(0xd800)])
	array.properties = [
		StructuredProperty{key: '2', value: &object_value},
		StructuredProperty{key: 'tail', value: &object_value},
		StructuredProperty{key: lone_key.str(), key_utf16_: lone_key, value: &array_value},
	]
	record := structured_serialize(array_value)!
	decoded := structured_object_from_value(structured_deserialize(record)!)!
	assert decoded.array_length? == u32(-1)
	assert decoded.values.len == 0
	assert decoded.properties.len == 3
	assert decoded.properties[0].value.object_data == decoded.properties[1].value.object_data
	assert decoded.properties[2].value.object_data == voidptr(decoded)
	assert decoded.properties[2].key_utf16_?.code_units() == [u16(0xd800)]
	assert structured_serialize(structured_object_value(decoded))!.data == record.data
	plain := structured_object_from_value(structured_deserialize(SerializationRecord{data: [u8(18), 255, 255, 255, 255]})!)!
	assert plain.null_prototype
}

fn test_source_ipc_collection_records_reject_invalid_lengths_and_property_framing() {
	for data in [[u8(13), 255, 255, 255, 255, 255, 255, 255, 255],
		[u8(14), 1, 0, 0, 0, 0, 0, 0, 0], [u8(17), 2],
		[u8(15), 0, 0, 0, 0, 1, 0, 0, 0, 255]] {
		if _ := structured_deserialize(SerializationRecord{data: data}) { assert false } else { assert err.msg().contains('DataCloneError') }
	}
}
