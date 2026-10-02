module webidl

import libjs

fn test_source_dom_exception_fields_keep_utf16_storage_units_and_source_payload_order() {
	name := libjs.utf16_string_from_code_units([u16(78), 0, 0xd800, 0xdc01])
	message := libjs.utf16_string_from_code_units([u16(0xdc00), 65, 0xd800])
	exception := DOMException.create_utf16_record(name, message)
	assert exception.name_utf16().code_units() == name.code_units()
	assert exception.message_utf16().code_units() == message.code_units()
	assert exception.code() == 0
	fields := exception.serialization_steps_utf16()
	assert fields[0].code_units() == name.code_units()
	assert fields[1].code_units() == message.code_units()
	mut decoded := DOMException{}
	decoded.deserialization_steps_utf16(fields)!
	assert decoded.name_utf16().code_units() == name.code_units()
	assert decoded.message_utf16().code_units() == message.code_units()
	// Public value construction must copy the source record rather than discard
	// its actual UTF16 storage in a diagnostic string projection.
	value := dom_exception_value(*exception)
	assert value.dom_exception_?.name_utf16().code_units() == name.code_units()
	assert value.dom_exception_?.message_utf16().code_units() == message.code_units()
	if _ := decoded.deserialization_steps_utf16([name]) { assert false }
}

fn test_source_dom_exception_storage_flag_and_compatibility_update_keep_actual_current_fields() {
	name := libjs.utf16_string_from_code_units_with_storage([u16(69), 114, 114, 111, 114], false)!
	message := libjs.utf16_string_from_code_units_with_storage([u16(65)], false)!
	mut exception := DOMException.create_utf16_record(name, message)
	assert !exception.name_utf16().has_ascii_storage()
	assert !exception.message_utf16().has_ascii_storage()
	assert !dom_exception_value(*exception).dom_exception_?.name_utf16().has_ascii_storage()
	exception.deserialization_steps(['NetworkError', 'replacement'])!
	assert exception.name_utf16().code_units() == libjs.utf16_string('NetworkError').code_units()
	assert exception.message_utf16().code_units() == libjs.utf16_string('replacement').code_units()
	assert exception.name_utf16().has_ascii_storage()
	assert exception.code() == 19
}
