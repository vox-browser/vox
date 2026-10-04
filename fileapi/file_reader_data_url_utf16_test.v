module fileapi

import libjs

fn test_source_data_url_package_retains_unchecked_ascii_owner_and_char_units() {
	mime := libjs.utf16_string_from_code_units([u16(`x`), 0xd800, 0, 0x00e9]).str()
	result := blob_package_data([u8(255), 0], .data_url, mime, none)!
	raw := result.string_utf16_record()?
	assert raw.has_ascii_storage() && !raw.has_short_ascii_storage()
	assert raw.str() == result.text
	assert raw.code_units().len == result.text.len
	for index, unit in raw.code_units() {
		assert unit == u16(char(result.text.bytes()[index]))
	}
	assert raw.code_units() != libjs.utf16_string_from_utf8_without_validation(result.text).code_units()
	assert result.clone().string_utf16_record()?.code_units() == raw.code_units()
	mut reader := FileReader.create()
	reader.set_result(result)
	assert reader.result().string_utf16_record()?.has_ascii_storage()
	assert reader.result().string_utf16_record()?.str() == result.text
	mut units := reader.result().string_utf16_record()?.code_units()
	units[0] = 0
	assert reader.result().string_utf16_record()?.code_units()[0] == u16(`d`)
	stale := FileReaderResult{ ...result, text: 'changed' }
	assert stale.string_utf16_record() == none
}

fn test_source_data_url_default_empty_and_sync_paths_keep_actual_ascii_records() {
	result := blob_package_data([], .data_url, none, none)!
	assert result.text == 'data:application/octet-stream;base64,'
	assert result.string_utf16_record()?.has_ascii_storage()
	assert result.string_utf16_record()?.code_units().len == result.text.len
	reader := FileReaderSync.create()
	owned := reader.read_as(Blob.create([], 'text/plain'), .data_url, none)!
	assert owned.string_utf16_record()?.str() == 'data:text/plain;base64,'
	assert owned.string_utf16_record()?.has_ascii_storage()
}
