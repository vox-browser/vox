module fileapi

import libjs

fn test_source_file_reader_binary_string_appends_each_of_all_256_byte_code_units() {
	mut bytes := []u8{cap: 256}
	for index in 0 .. 256 { bytes << u8(index) }
	raw := file_reader_binary_string(bytes)
	assert raw.code_units().len == 256
	assert !raw.has_ascii_storage()
	units := raw.code_units()
	for index in 0 .. 256 {
		assert units[index] == u16(index)
	}
	result := FileReader.blob_package_data(bytes, .binary_string, none, none)!
	assert result.kind == .string_
	assert libjs.utf16_string_from_utf8_without_validation(result.text).code_units() == units
	bytes[0] = 99
	assert raw.code_units()[0] == 0
}

fn test_source_file_reader_binary_string_preserves_embedded_null_and_bom_bytes_verbatim() {
	bytes := [u8(0), 0x41, 0, 0xff, 0xfe, 0xef, 0xbb, 0xbf, 0x80, 0xc0, 0]
	expected := [u16(0), 0x41, 0, 0xff, 0xfe, 0xef, 0xbb, 0xbf, 0x80, 0xc0, 0]
	assert file_reader_binary_string(bytes).code_units() == expected
	assert file_reader_binary_string([]).code_units().len == 0
	assert file_reader_binary_string([u8(0), 0x41, 0x7f]).has_ascii_storage()
	reader := FileReaderSync.construct_impl()
	result := reader.read_as_binary_string(Blob.create(bytes, 'text/plain;charset=utf-16'))!
	assert libjs.utf16_string_from_utf8_without_validation(result).code_units() == expected
	assert result.bytes()[0] == 0 && result.bytes()[result.len - 1] == 0
}
