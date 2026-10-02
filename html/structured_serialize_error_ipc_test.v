module html

import libjs

fn test_source_ipc_error_type_order_and_optional_empty_message_goldens() {
	for index, name in ['Error', 'EvalError', 'InternalError', 'RangeError', 'ReferenceError', 'SyntaxError', 'TypeError', 'URIError'] {
		mut object := StructuredObject.create(.error_object)
		object.error_type = error_name_to_type(name)
		assert u8(object.error_type) == u8(index)
		record := structured_serialize(structured_object_value(object))!
		assert record.data == [u8(16), u8(index), 0, 0]
		decoded := structured_object_from_value(structured_deserialize(record)!)!
		assert decoded.error_type == object.error_type
		assert !decoded.has_message && !decoded.has_cause
		object.has_message = true
		assert structured_serialize(structured_object_value(object))!.data == [u8(16), u8(index), 1, 1, 0, 0, 0, 0, 0]
	}
}

fn test_source_ipc_error_message_and_cause_retain_original_utf16_units_and_storage() {
	mut object := StructuredObject.create(.error_object)
	object.error_type = .type_error
	object.string_utf16_ = libjs.utf16_string_from_code_units([u16(0xd800)])
	object.cause_utf16_ = libjs.utf16_string_from_code_units_with_storage([u16(65)], false)!
	golden := [u8(16), 6, 1, 0, 1, 0, 0, 0, 0, 216, 1, 0, 1, 0, 0, 0, 65, 0]
	assert structured_serialize(structured_object_value(object))!.data == golden
	decoded := structured_object_from_value(structured_deserialize(SerializationRecord{data: golden})!)!
	assert decoded.has_message && decoded.has_cause
	assert decoded.string_utf16_?.code_units() == [u16(0xd800)]
	assert !decoded.cause_utf16_?.has_ascii_storage()
	assert decoded.cause_utf16_?.code_units() == [u16(65)]
	assert structured_serialize(structured_object_value(decoded))!.data == golden
}

fn test_source_ipc_error_decoder_rejects_unknown_types_optional_flags_and_truncation() {
	for data in [[u8(16), 8, 0, 0], [u8(16), 0, 2], [u8(16), 0, 0, 2], [u8(16), 0, 1, 1, 1, 0, 0, 0], [u8(16), 0, 0]] {
		if _ := structured_deserialize(SerializationRecord{data: data}) { assert false } else { assert err.msg().contains('DataCloneError') }
	}
}

fn test_source_ipc_regexp_payload_retains_original_source_and_flags_utf16_storage() {
	mut object := StructuredObject.create(.regexp)
	object.string_utf16_ = libjs.utf16_string_from_code_units([u16(0xd800)])
	object.second_string_utf16_ = libjs.utf16_string_from_code_units_with_storage([u16(103)], false)!
	golden := [u8(12), 0, 1, 0, 0, 0, 0, 216, 0, 1, 0, 0, 0, 103, 0]
	assert structured_serialize(structured_object_value(object))!.data == golden
	decoded := structured_object_from_value(structured_deserialize(SerializationRecord{data: golden})!)!
	assert decoded.string_utf16_?.code_units() == [u16(0xd800)]
	assert !decoded.second_string_utf16_?.has_ascii_storage()
	assert structured_serialize(structured_object_value(decoded))!.data == golden
}
