module webidl

import libjs

fn test_source_primitive_utf16_slot_preserves_raw_units_and_excludes_stale_compatibility_text() {
	units := [u16(0xd800), 0, 0xdc00, 0xd83d, 0xde00, 0xd801, 0xd802, 0xdc01]
	original := libjs.utf16_string_from_code_units(units)
	value := string_utf16_value(original)
	assert value.kind == .string_
	assert value.string_utf16().code_units() == units
	assert to_utf16_string(value)! == units
	assert to_string(value)! == original.str()
	mut detached := value.string_utf16().code_units()
	detached[0] = 0
	assert value.string_utf16().code_units() == units
	updated := Value{ ...value, string_value: 'ordinary' }
	assert updated.string_utf16().code_units() == libjs.utf16_string('ordinary').code_units()
	assert to_utf16_string(updated)! == libjs.utf16_string('ordinary').code_units()
}

fn test_source_utf16_usv_string_uses_existing_ak_well_formed_operation() {
	value := string_utf16_value(libjs.utf16_string_from_code_units([u16(0xd800), 0, 0xdc00, 0xd83d,
		0xde00, 0xd801, 0xd802, 0xdc01]))
	assert to_utf16_usv_string(value)! == [u16(0xfffd), 0, 0xfffd, 0xd83d, 0xde00, 0xfffd, 0xd802,
		0xdc01]
	assert libjs.utf16_string(to_usv_string(value)!).code_units() == [u16(0xfffd), 0, 0xfffd, 0xd83d,
		0xde00, 0xfffd, 0xd802, 0xdc01]
	if _ := to_byte_string(value) {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
	assert to_utf16_usv_string(string_value('ordinary'))! == libjs.utf16_string('ordinary').code_units()
	assert to_usv_string(number_value(12))! == '12'
}
