module fileapi

import libjs

fn test_source_file_reader_data_url_package_uses_default_and_literal_supplied_mime() {
	bytes := [u8(0xff), 0]
	assert blob_package_data(bytes, .data_url, none, none)!.text == 'data:application/octet-stream;base64,/wA='
	assert blob_package_data(bytes, .data_url, '', 'UTF-16LE')!.text == 'data:application/octet-stream;base64,/wA='
	assert blob_package_data(bytes, .data_url, 'text/plain;name="a?b#c %"', 'UTF-16LE')!.text == 'data:text/plain;name="a?b#c %";base64,/wA='
	assert blob_package_data([], .data_url, 'text/plain', none)!.text == 'data:text/plain;base64,'
	assert blob_package_data([], .data_url, 'invalid-mime', none)!.text == 'data:invalid-mime;base64,'
}

fn test_source_file_reader_data_url_compatibility_projection_retains_raw_serialized_bytes() {
	// Source's unchecked ASCII record converts to UTF8 by retaining its bytes.
	// This checks only that compatibility projection, not raw ASCII code-unit
	// metadata or its native PrimitiveString exposure.
	mime := libjs.utf16_string_from_code_units([u16(`x`), 0xd800, 0, 0x00e9]).str()
	result := blob_package_data([u8(0xff), 0], .data_url, mime, none)!
	assert result.kind == .string_
	mut expected := 'data:'.bytes()
	expected << [u8(`x`), 0xed, 0xa0, 0x80, 0, 0xc3, 0xa9]
	expected << ';base64,/wA='.bytes()
	assert result.text.bytes() == expected
	reader := FileReaderSync.construct_impl()
	assert reader.read_as_data_url(Blob.create_utf16([u8(0xff), 0],
		libjs.utf16_string_from_code_units([u16(`x`), 0xd800, 0, 0x00e9])))!.bytes() == expected
}
