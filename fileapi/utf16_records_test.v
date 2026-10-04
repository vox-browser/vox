module fileapi

import libjs

fn test_source_blob_file_raw_utf16_slots_survive_typed_payloads_and_list_records() {
	type_ := libjs.utf16_string_from_code_units([u16(0xd800), 0])
	name := libjs.utf16_string_from_code_units([u16(0xdc00), 0xd801, 0, 0xd83d, 0xde00])
	mut bytes := [u8(7), 9]
	blob := Blob.create_utf16(bytes, type_)
	file := File.create_utf16(bytes, name, type_, i64(-7))
	bytes[0] = 0
	assert blob.raw_bytes() == [u8(7), 9]
	assert file.raw_bytes() == [u8(7), 9]
	assert blob.type_utf16().code_units() == type_.code_units()
	assert file.type_utf16().code_units() == type_.code_units()
	assert file.name_utf16().code_units() == name.code_units()
	restored_blob := Blob.deserialization_steps(blob.serialization_steps())
	restored_file := File.deserialization_steps(file.serialization_steps())
	assert restored_blob.type_utf16().code_units() == type_.code_units()
	assert restored_file.type_utf16().code_units() == type_.code_units()
	assert restored_file.name_utf16().code_units() == name.code_units()
	assert restored_file.last_modified() == -7
	assert voidptr(restored_blob) != voidptr(blob) && voidptr(restored_file) != voidptr(file)
	mut list := FileList.create()
	list.add_file(file)
	restored_list := FileList.deserialization_steps(list.serialization_steps())
	assert restored_list.item(0)?.name_utf16().code_units() == name.code_units()
	assert restored_list.item(0)?.type_utf16().code_units() == type_.code_units()
}

fn test_source_fileapi_raw_slot_owners_retain_storage_flags_and_reject_stale_compatibility_text() {
	type_ := libjs.utf16_string_from_code_units_with_storage([u16(`A`), u16(`B`)], false)!
	blob := Blob.create_utf16([], type_)
	assert !blob.type_utf16().has_ascii_storage()
	assert !Blob.deserialization_steps(blob.serialization_steps()).type_utf16().has_ascii_storage()
	value := blob.serialization_steps()
	updated := SerializedBlob{ ...value, type_: 'new' }
	assert Blob.deserialization_steps(updated).type_utf16().str() == 'new'
	file := File.create_utf16([], type_, type_, 0)
	file_value := file.serialization_steps()
	changed_file := SerializedFile{ ...file_value, name: 'new name', type_: 'new type' }
	restored := File.deserialization_steps(changed_file)
	assert restored.name_utf16().str() == 'new name'
	assert restored.type_utf16().str() == 'new type'
	mut detached := blob.type_utf16().code_units()
	detached[0] = 0
	assert blob.type_utf16().code_units() == [u16(`A`), u16(`B`)]
}
