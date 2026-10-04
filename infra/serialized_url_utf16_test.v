module infra

fn test_source_serialized_url_helper_returns_owned_raw_ascii_storage() {
	for input in ['', 'data:x', 'data:text/plain;base64,AA=='] {
		record := utf16_string_record_from_url_ascii(input)
		assert record.has_ascii_storage()
		assert record.str() == input
		assert record.code_units().len == input.len
		assert record.has_short_ascii_storage() == (input.len <= int(sizeof(voidptr)) - 1)
	}
	mut bytes := [u8(`x`), 0, 0xed, 0xa0, 0x80, 255]
	record := utf16_string_record_from_url_ascii(bytes.bytestr())
	assert record.has_ascii_storage()
	assert record.str().bytes() == bytes
	for index, unit in record.code_units() {
		assert unit == u16(char(bytes[index]))
	}
	bytes[0] = u8(`z`)
	assert record.code_units()[0] == u16(`x`)
}
