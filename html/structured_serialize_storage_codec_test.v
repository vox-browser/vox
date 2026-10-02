module html

import dom
import libjs
import math
import webidl

fn test_source_lbsc_storage_envelope_and_signed_int32_leb128_goldens() {
	assert structured_serialize_for_storage(dom.js_undefined())!.data == [u8(76), 66, 83, 67, 1, 0, 1]
	assert structured_serialize_for_storage(dom.js_null())!.data == [u8(76), 66, 83, 67, 1, 0, 2]
	assert structured_serialize_for_storage(dom.js_bool(true))!.data == [u8(76), 66, 83, 67, 1, 0, 3, 1]
	for number, payload in {
		i32(0): [u8(0)]
		i32(-1): [u8(127)]
		i32(63): [u8(63)]
		i32(64): [u8(192), 0]
		i32(-64): [u8(64)]
		i32(-65): [u8(191), 127]
		i32(2147483647): [u8(255), 255, 255, 255, 7]
		i32(-2147483648): [u8(128), 128, 128, 128, 120]
	} {
		mut expected := [u8(76), 66, 83, 67, 1, 0, 25]
		expected << payload
		record := structured_serialize_for_storage(dom.js_number(f64(number)))!
		assert record.type_ == .storage
		assert record.data == expected
		assert structured_deserialize(record)!.number_data == f64(number)
	}
	negative_zero := math.f64_from_bits(u64(1) << 63)
	assert structured_serialize_for_storage(dom.js_number(negative_zero))!.data == [u8(76), 66, 83, 67, 1, 0, 4, 0, 0, 0, 0, 0, 0, 0, 128]
	assert math.f64_bits(structured_deserialize(structured_serialize_for_storage(dom.js_number(negative_zero))!)!.number_data) == math.f64_bits(negative_zero)
}

fn test_source_lbsc_utf16_length_header_bytes_and_storage_decode_construction() {
	assert structured_serialize_for_storage(dom.js_string('A'))!.data == [u8(76), 66, 83, 67, 1, 0, 5, 3, 65]
	lone := dom.js_utf16_string(libjs.utf16_string_from_code_units([u16(0xd800)]))
	golden := [u8(76), 66, 83, 67, 1, 0, 5, 2, 0, 216]
	assert structured_serialize_for_storage(lone)!.data == golden
	decoded := structured_deserialize(SerializationRecord{type_: .storage, data: golden})!
	assert decoded.string_utf16_?.code_units() == [u16(0xd800)]
	// Source storage decode calls from_utf16 and compresses all-ASCII input;
	// IPC from_ipc_stream alone retains a false storage flag on ASCII units.
	ascii_utf16 := [u8(76), 66, 83, 67, 1, 0, 5, 2, 65, 0]
	ascii := structured_deserialize(SerializationRecord{type_: .storage, data: ascii_utf16})!
	assert ascii.string_utf16_?.has_ascii_storage()
	assert structured_serialize_for_storage(ascii)!.data == [u8(76), 66, 83, 67, 1, 0, 5, 3, 65]
	long_ascii := structured_serialize_for_storage(dom.js_string('A'.repeat(64)))!
	assert long_ascii.data[7..9] == [u8(129), 1]
}

fn test_source_lbsc_collections_buffer_capacity_and_error_name_payload_goldens() {
	mut object := StructuredObject.create(.object)
	item := dom.js_null()
	object.properties = [StructuredProperty{key: 'x', value: &item}]
	assert structured_serialize_for_storage(structured_object_value(object))!.data == [u8(76), 66, 83, 67, 1, 0, 17, 2, 3, 120, 255]
	mut array := StructuredObject.create(.array)
	array.values = [&item]
	assert structured_serialize_for_storage(structured_object_value(array))!.data == [u8(76), 66, 83, 67, 1, 0, 15, 1, 2, 3, 48, 255]
	mut map_object := StructuredObject.create(.map)
	key := dom.js_bool(true)
	map_object.entries = [StructuredMapEntry{key: &key, value: &item}]
	assert structured_serialize_for_storage(structured_object_value(map_object))!.data == [u8(76), 66, 83, 67, 1, 0, 13, 1, 3, 1, 2]
	mut set := StructuredObject.create(.set)
	set.values = [&item]
	assert structured_serialize_for_storage(structured_object_value(set))!.data == [u8(76), 66, 83, 67, 1, 0, 14, 1, 2]
	mut buffer := StructuredObject.create(.array_buffer)
	buffer.bytes = [u8(170)]
	buffer.max_byte_length = u64(4294967313)
	assert structured_serialize_for_storage(structured_object_value(buffer))!.data == [u8(76), 66, 83, 67, 1, 0, 21, 1, 170, 145, 128, 128, 128, 16]
	mut error_object := StructuredObject.create(.error_object)
	error_object.error_type = .type_error
	assert structured_serialize_for_storage(structured_object_value(error_object))!.data == [u8(76), 66, 83, 67, 1, 0, 16, 19, 84, 121, 112, 101, 69, 114, 114, 111, 114, 0, 0]
	for value in [structured_object_value(object), structured_object_value(array), structured_object_value(buffer), structured_object_value(error_object)] {
		record := structured_serialize_for_storage(value)!
		assert structured_serialize_for_storage(structured_deserialize(record)!)!.data == record.data
	}
}

fn test_source_lbsc_bigint_signed_magnitude_and_object_cycles_keep_source_payloads() {
	for text, sign in {'18446744073709551616': u8(0), '-18446744073709551616': u8(1)} {
		integer := libjs.string_to_bigint(libjs.utf16_string(text)) or { panic('missing source BigInt') }
		value := dom.js_webidl_value(webidl.bigint_value_for_record(integer))
		record := structured_serialize_for_storage(value)!
		assert record.data == [u8(76), 66, 83, 67, 1, 0, 6, 10, sign, 1, 0, 0, 0, 0, 0, 0, 0, 0]
		assert webidl.value_to_bigint(structured_deserialize(record)!.as_webidl_value()!)!.big_integer.str() == text
	}
	mut object := StructuredObject.create(.object)
	value := structured_object_value(object)
	object.properties = [StructuredProperty{key: 'x', value: &value}]
	record := structured_serialize_for_storage(value)!
	assert record.data == [u8(76), 66, 83, 67, 1, 0, 17, 18, 0, 3, 120, 255]
	decoded := structured_object_from_value(structured_deserialize(record)!)!
	assert decoded.properties[0].value.object_data == voidptr(decoded)
}

fn test_source_lbsc_rejects_bad_envelope_integer_width_and_trailing_bytes() {
	for data in [[u8(76), 66, 83, 68, 1, 0, 2], [u8(76), 66, 83, 67, 2, 0, 2],
		[u8(76), 66, 83, 67, 1, 1, 2], [u8(76), 66, 83, 67, 1, 0, 2, 2],
		[u8(76), 66, 83, 67, 1, 0, 25, 128],
		[u8(76), 66, 83, 67, 1, 0, 25, 128, 128, 128, 128, 8],
		[u8(76), 66, 83, 67, 1, 0, 25, 128, 128, 128, 128, 128],
		[u8(76), 66, 83, 67, 1, 0, 15, 128, 128, 128, 128, 128, 128, 128, 128, 128, 2],
		[u8(76), 66, 83, 67, 1, 0, 5, 3, 128], [u8(76), 66, 83, 67, 1, 0, 5, 254, 255, 255, 255, 255, 255, 255, 255, 255, 1]] {
		if _ := structured_deserialize(SerializationRecord{type_: .storage, data: data}) { assert false } else { assert err.msg().contains('DataCloneError') }
	}
	// Source IPC entrypoint does not require full consumption; strict
	// compatibility convenience still rejects the same trailing record.
	assert structured_deserialize_ipc(SerializationRecord{data: [u8(2), 2]})!.kind == .null_
	if _ := structured_deserialize(SerializationRecord{data: [u8(2), 2]}) { assert false } else { assert err.msg().contains('trailing') }
}
