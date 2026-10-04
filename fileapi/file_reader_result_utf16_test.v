module fileapi

import libjs

fn test_source_reader_binary_and_text_packages_retain_actual_owned_utf16_slots() {
	mut bytes := []u8{cap: 256}
	for index in 0 .. 256 { bytes << u8(index) }
	binary := blob_package_data(bytes, .binary_string, none, none)!
	raw := binary.string_utf16_record()?
	assert raw.code_units().len == 256 && !raw.has_ascii_storage()
	units := raw.code_units()
	for index in 0 .. 256 {
		assert units[index] == u16(index)
	}
	bytes[0] = 99
	assert raw.code_units()[0] == 0 && binary.clone().string_utf16_record()?.code_units() == units
	text := blob_package_data([u8(0xef), 0xbb, 0xbf, 0x41, 0, 0xf0, 0x9f, 0x98, 0x80], .text,
		none, 'windows-1252')!
	assert text.string_utf16_record()?.code_units() == [u16(0x41), 0, 0xd83d, 0xde00]
	assert text.text.bytes() == [u8(0x41), 0, 0xf0, 0x9f, 0x98, 0x80]
	assert blob_package_data([u8(0xff)], .text, none, none)!.string_utf16_record()?.code_units() == [u16(0xfffd)]
	assert blob_package_data('short'.bytes(), .text, none, none)!.string_utf16_record()?.has_short_ascii_storage()
	assert blob_package_data([], .text, none, none)!.string_utf16_record()?.code_units().len == 0
}

fn test_source_reader_result_clone_set_and_access_preserve_lone_units_and_original_storage() {
	mut units := [u16(0x41), 0, 0xd800, 0xdc00, 0xdbff]
	raw := libjs.utf16_string_from_code_units(units)
	value := file_reader_utf16_result(raw)
	mut reader := FileReader.create()
	reader.set_result(value)
	units[0] = 0x42
	assert reader.result().string_utf16_record()?.code_units() == [u16(0x41), 0, 0xd800, 0xdc00,
		0xdbff]
	mut copy := reader.result().string_utf16_record()?.code_units()
	copy[0] = 0x43
	assert reader.result().string_utf16_record()?.code_units()[0] == 0x41
	wide_ascii := libjs.utf16_string_from_code_units_with_storage([u16(0x41)], false)!
	reader.set_result(file_reader_utf16_result(wide_ascii))
	assert !reader.result().string_utf16_record()?.has_ascii_storage()
	reader.abort()
	assert reader.result().kind == .null_ && reader.result().string_utf16_record() == none
}

fn test_source_reader_raw_result_slot_rejects_stale_compatibility_dtos_and_leaves_data_url_boundary_absent() {
	value := file_reader_utf16_result(libjs.utf16_string_from_code_units([u16(0xd800)]))
	stale := FileReaderResult{ ...value, text: 'updated' }
	assert stale.string_utf16_record() == none && stale.clone().string_utf16_record() == none
	non_string := FileReaderResult{ ...value, kind: .bytes }
	assert non_string.string_utf16_record() == none
	assert file_reader_string_result('compatibility').string_utf16_record() == none
	assert blob_package_data([u8(0)], .data_url, 'text/plain', none)!.string_utf16_record() == none
	assert blob_package_data([u8(0)], .array_buffer, none, none)!.string_utf16_record() == none
	mut reader := FileReader.create()
	reader.read_as_binary_string(Blob.create([u8(0), 255], ''))!
	reader.process_pending_tasks()
	assert reader.result().string_utf16_record()?.code_units() == [u16(0), 255]
	reader.read_as_text(Blob.create('next'.bytes(), ''), none)!
	assert reader.result().string_utf16_record() == none
}
