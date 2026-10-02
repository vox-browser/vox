module html

import dom
import libjs
import webidl

fn test_source_ipc_utf16_storage_goldens_preserve_code_units_and_lone_surrogates() {
	assert structured_serialize(dom.js_string('A'))!.data == [u8(5), 1, 1, 0, 0, 0, 65]
	assert structured_serialize(dom.js_string('😀'))!.data == [u8(5), 0, 2, 0, 0, 0, 0x3d, 0xd8, 0, 0xde]
	for units in [[u16(0xd800)], [u16(0xdc00)], [u16(0x41), 0xd800, 0xdc00, 0xdfff, 0]] {
		text := libjs.utf16_string_from_code_units(units)
		record := structured_serialize(dom.js_utf16_string(text))!
		decoded := structured_deserialize(record)!
		assert decoded.string_utf16_?.code_units() == units
		assert structured_serialize(decoded)!.data == record.data
		mut object := StructuredObject.create(.string_object)
		object.string_utf16_ = text
		cloned := structured_object_from_value(structured_deserialize(structured_serialize(structured_object_value(object))!)!)!
		assert cloned.string_utf16_?.code_units() == units
	}
	for data in [[u8(5), 2], [u8(5), 0, 1, 0, 0, 0, 0xd8], [u8(5), 1, 1, 0, 0, 0, 0xff]] {
		if _ := structured_deserialize(SerializationRecord{data: data}) { assert false } else { assert err.msg().contains('DataCloneError') }
	}
}

fn test_source_ipc_bigint_sign_magnitude_goldens_preserve_arbitrary_width_and_object_brand() {
	assert structured_serialize(dom.js_webidl_value(webidl.bigint_value(-256)))!.data == [u8(6), 3, 0, 0, 0, 1, 1, 0]
	assert structured_serialize(dom.js_webidl_value(webidl.bigint_value(0)))!.data == [u8(6), 1, 0, 0, 0, 0]
	for text in ['18446744073709551615', '-340282366920938463463374607431768211457'] {
		integer := webidl.value_to_bigint(webidl.string_value(text))!
		primitive := dom.js_webidl_value(webidl.bigint_value_for_record(integer))
		decoded := structured_deserialize(structured_serialize(primitive)!)!
		assert webidl.value_to_bigint(decoded.as_webidl_value()!)!.big_integer.str() == text
		mut object := StructuredObject.create(.big_int_object)
		object.bigint_data = integer
		cloned := structured_object_from_value(structured_deserialize(structured_serialize(structured_object_value(object))!)!)!
		assert cloned.kind == .big_int_object
		assert cloned.bigint_data?.big_integer.str() == text
	}
	if _ := structured_deserialize(SerializationRecord{data: [u8(6), 0, 0, 0, 0]}) { assert false } else { assert err.msg().contains('BigInt') }
}
