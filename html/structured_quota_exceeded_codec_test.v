module html

import libjs
import math
import webidl

fn quota_codec_context() StructuredDeserializationContext {
	return StructuredDeserializationContext{is_exposed: fn (interface_name StructuredSerializableInterface) bool { return interface_name == .quota_exceeded_error }}
}

fn test_source_quota_payload_ipc_and_storage_optional_double_goldens() {
	exception := webidl.QuotaExceededError.construct_utf16(libjs.utf16_string_from_code_units([u16(0xd800), 0]), webidl.QuotaExceededErrorOptions{quota: 0, requested: 2.5})!
	object := StructuredObject.create_quota_exceeded_error(&exception)
	assert u16(StructuredSerializableInterface.quota_exceeded_error) == 569
	ipc := structured_serialize(structured_object_value(object))!
	assert ipc.data == [u8(24), 57, 2, 1, 18, 0, 0, 0, 81, 117, 111, 116, 97, 69, 120, 99, 101, 101, 100, 101, 100, 69, 114, 114, 111, 114, 0, 2, 0, 0, 0, 0, 216, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 4, 64]
	storage := structured_serialize_for_storage(structured_object_value(object))!
	assert storage.data == [u8(76), 66, 83, 67, 1, 0, 24, 37, 81, 117, 111, 116, 97, 69, 120, 99, 101, 101, 100, 101, 100, 69, 114, 114, 111, 114, 1, 37, 81, 117, 111, 116, 97, 69, 120, 99, 101, 101, 100, 101, 100, 69, 114, 114, 111, 114, 4, 0, 216, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 4, 64]
	for record in [ipc, storage] {
		decoded := structured_object_from_value(structured_deserialize_with_context(record, quota_codec_context())!)!
		assert decoded.serializable_interface_? == .quota_exceeded_error
		assert decoded.dom_exception_ == none
		assert decoded.quota_exceeded_error_?.base.message_utf16().code_units() == [u16(0xd800), 0]
		assert decoded.quota_exceeded_error_?.quota()? == 0
		assert decoded.quota_exceeded_error_?.requested()? == 2.5
		assert voidptr(decoded.quota_exceeded_error_?) != voidptr(&exception)
		if _ := structured_deserialize_with_context(record, StructuredDeserializationContext{is_exposed: fn (interface_name StructuredSerializableInterface) bool { return interface_name == .dom_exception }}) { assert false } else { assert err.msg().contains('unsupported type') }
	}
}

fn test_source_quota_deserialization_keeps_raw_optional_double_bits_and_aliases() {
	mut exception := webidl.QuotaExceededError{}
	exception.deserialization_steps_utf16(webidl.SerializedQuotaExceededErrorUTF16{name: libjs.utf16_string('QuotaExceededError'), message: libjs.utf16_string('raw'), quota: math.f64_from_bits(0x8000000000000000), requested: math.f64_from_bits(0x7ff8000000000042)})
	mut root := StructuredObject.create(.array)
	object := StructuredObject.create_quota_exceeded_error(&exception)
	value := structured_object_value(object)
	root.values = [&value, &value]
	for for_storage in [false, true] {
		record := if for_storage { structured_serialize_for_storage(structured_object_value(root))! } else { structured_serialize(structured_object_value(root))! }
		decoded := structured_object_from_value(structured_deserialize_with_context(record, quota_codec_context())!)!
		assert decoded.values[0].object_data == decoded.values[1].object_data
		cloned := structured_object_from_value(*decoded.values[0])!.quota_exceeded_error_?
		assert math.f64_bits(cloned.quota()?) == u64(0x8000000000000000)
		assert math.f64_bits(cloned.requested()?) == u64(0x7ff8000000000042)
	}
	// The source deserializer assigns internal slots directly, including raw
	// values that the author constructor rejects.
	exception.deserialization_steps_utf16(webidl.SerializedQuotaExceededErrorUTF16{name: libjs.utf16_string('QuotaExceededError'), message: libjs.utf16_string('raw'), quota: -2, requested: math.inf(1)})
	record := structured_serialize(structured_object_value(StructuredObject.create_quota_exceeded_error(&exception)))!
	cloned := structured_object_from_value(structured_deserialize_with_context(record, quota_codec_context())!)!.quota_exceeded_error_?
	assert cloned.quota()? == -2
	assert math.is_inf(cloned.requested()?, 1)
}

fn test_source_quota_absence_truncation_and_storage_bool_validation() {
	exception := webidl.QuotaExceededError.create('')
	object := StructuredObject.create_quota_exceeded_error(&exception)
	for for_storage in [false, true] {
		record := if for_storage { structured_serialize_for_storage(structured_object_value(object))! } else { structured_serialize(structured_object_value(object))! }
		assert record.data[record.data.len - 2..] == [u8(0), 0]
		cloned := structured_object_from_value(structured_deserialize_with_context(record, quota_codec_context())!)!.quota_exceeded_error_?
		assert cloned.quota() == none
		assert cloned.requested() == none
		if _ := structured_deserialize_with_context(SerializationRecord{data: record.data[..record.data.len - 1], type_: record.type_}, quota_codec_context()) { assert false }
		mut invalid := record.data.clone()
		invalid[invalid.len - 2] = 1
		if _ := structured_deserialize_with_context(SerializationRecord{data: invalid, type_: record.type_}, quota_codec_context()) { assert false }
		if for_storage {
			invalid[invalid.len - 2] = 2
			if _ := structured_deserialize_with_context(SerializationRecord{data: invalid, type_: .storage}, quota_codec_context()) { assert false } else { assert err.msg().contains('bool') }
		}
	}
}
