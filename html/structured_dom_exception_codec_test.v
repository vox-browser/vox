module html

import libjs
import webidl

fn dom_exception_codec_context() StructuredDeserializationContext {
	return StructuredDeserializationContext{is_exposed: fn (interface_name StructuredSerializableInterface) bool { return interface_name == .dom_exception }}
}

fn test_source_serializable_dom_exception_ipc_primary_interface_and_payload_goldens() {
	exception := webidl.DOMException.create_utf16_record(libjs.utf16_string('AbortError'), libjs.utf16_string_from_code_units([u16(0xd800), 0]))
	object := StructuredObject.create_dom_exception(exception)
	assert u16(StructuredSerializableInterface.dom_exception) == 568
	record := structured_serialize(structured_object_value(object))!
	assert record.data == [u8(24), 56, 2, 1, 10, 0, 0, 0, 65, 98, 111, 114, 116, 69, 114, 114, 111, 114, 0, 2, 0, 0, 0, 0, 216, 0, 0]
	decoded := structured_object_from_value(structured_deserialize_ipc_with_context(record, dom_exception_codec_context())!)!
	assert decoded.serializable_interface_? == .dom_exception
	assert decoded.dom_exception_?.name_utf16().code_units() == exception.name_utf16().code_units()
	assert decoded.dom_exception_?.message_utf16().code_units() == [u16(0xd800), 0]
	assert decoded.dom_exception_?.code() == 20
	assert voidptr(decoded.dom_exception_?) != voidptr(exception)
	if _ := structured_deserialize_ipc(record) { assert false } else { assert err.msg().contains('unsupported type') }
}

fn test_source_serializable_dom_exception_storage_identifier_version_and_alias_memory() {
	exception := webidl.DOMException.create_utf16_record(libjs.utf16_string('AbortError'), libjs.utf16_string_from_code_units([u16(0xd800), 0]))
	object := StructuredObject.create_dom_exception(exception)
	record := structured_serialize_for_storage(structured_object_value(object))!
	assert record.data == [u8(76), 66, 83, 67, 1, 0, 24, 25, 68, 79, 77, 69, 120, 99, 101, 112, 116, 105, 111, 110, 1, 21, 65, 98, 111, 114, 116, 69, 114, 114, 111, 114, 4, 0, 216, 0, 0]
	decoded := structured_object_from_value(structured_deserialize_with_context(record, dom_exception_codec_context())!)!
	assert decoded.dom_exception_?.message_utf16().code_units() == [u16(0xd800), 0]
	mut root := StructuredObject.create(.array)
	value := structured_object_value(object)
	root.values = [&value, &value]
	for for_storage in [false, true] {
		container := if for_storage { structured_serialize_for_storage(structured_object_value(root))! } else { structured_serialize(structured_object_value(root))! }
		result := structured_object_from_value(structured_deserialize_with_context(container, dom_exception_codec_context())!)!
		assert result.values[0].object_data == result.values[1].object_data
	}
	mut invalid_version := record.data.clone()
	invalid_version[20] = 2
	if _ := structured_deserialize_with_context(SerializationRecord{data: invalid_version, type_: .storage}, dom_exception_codec_context()) { assert false } else { assert err.msg().contains('payload version') }
}

fn test_source_serializable_registry_validation_exposure_and_primary_subtype_are_distinct() {
	assert structured_serializable_interface_from_u16(569)! == .quota_exceeded_error
	assert structured_serializable_interface_from_name('DOMException')! == .dom_exception
	for invalid in [u16(0), 538, 65535] {
		if _ := structured_serializable_interface_from_u16(invalid) { assert false }
	}
	for data in [[u8(24), 0, 0], [u8(24), 56, 2, 1], [u8(24), 57, 2, 1]] {
		if _ := structured_deserialize_ipc_with_context(SerializationRecord{data: data}, dom_exception_codec_context()) { assert false }
	}
	// The primary derived interface must not become a base DOMException payload.
	mut object := StructuredObject.create_dom_exception(webidl.DOMException.create_record('QuotaExceededError', 'quota'))
	object.serializable_interface_ = .quota_exceeded_error
	if _ := structured_serialize(structured_object_value(object)) { assert false } else { assert err.msg().contains('QuotaExceededError') }
}
