module html

import dom
import libjs

fn test_source_ipc_all_ascii_utf16_storage_remains_utf16_after_decode_and_reserialize() {
	// Source PrimitiveString has additional empty/single-ASCII caches; this
	// long string exercises the actual from_ipc_stream storage contract.
	for count in [32] {
		mut data := [u8(5), 0, u8(count), 0, 0, 0]
		for _ in 0 .. count { data << [u8(65), 0] }
		decoded := structured_deserialize(SerializationRecord{data: data})!
		text := decoded.string_utf16_ or { panic('missing source string storage') }
		assert !text.has_ascii_storage()
		assert text.code_units() == []u16{len: count, init: u16(65)}
		assert structured_serialize(decoded)!.data == data
		mut object := StructuredObject.create(.string_object)
		object.string_utf16_ = text
		mut boxed := data.clone()
		boxed[0] = 9
		assert structured_serialize(structured_object_value(object))!.data == boxed
	}
	text := libjs.utf16_string_from_code_units_with_storage([]u16{len: 32, init: u16(65)}, false)!
	assert libjs.utf16_string_from_code_units([]u16{len: 32, init: u16(65)}).has_ascii_storage()
	assert libjs.utf16_string_from_code_units([u16(65)]).has_ascii_storage()
	assert !libjs.utf16_string_from_code_units([u16(65), 0xd800]).has_ascii_storage()
	mut vm := libjs.VM.create()
	assert !vm.create_string(text).utf16.has_ascii_storage()
	if _ := libjs.utf16_string_from_code_units_with_storage([u16(0xd800)], true) { assert false } else { assert err.msg().contains('invalid ASCII') }
	assert structured_deserialize(structured_serialize(dom.js_string('ASCII'))!)!.string_utf16_?.has_ascii_storage()
}
