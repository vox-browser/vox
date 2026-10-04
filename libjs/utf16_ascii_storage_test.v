module libjs

fn test_source_unchecked_ascii_owns_all_bytes_with_native_char_units() {
	mut input := []u8{len: 256, init: u8(index)}
	text := utf16_string_from_ascii_without_validation(input)
	assert text.has_ascii_storage()
	assert !text.has_short_ascii_storage()
	assert text.str().bytes() == input
	for index, unit in text.code_units() {
		assert unit == u16(char(u8(index)))
	}
	assert text.code_units()[0] == 0
	// The Source native macOS probe proves this signed plain-char projection.
	$if macos {
		assert text.code_units()[128] == 0xff80
		assert text.code_units()[255] == 0xffff
	}
	input[0] = u8(`Z`)
	assert text.code_units()[0] == 0
	assert text.str().bytes()[0] == 0
	mut returned := text.code_units()
	returned[255] = 0
	assert text.code_units()[255] == u16(char(u8(255)))
	copy := text.clone()
	assert copy.has_ascii_storage()
	assert copy.str().bytes()[255] == 255
	assert copy.code_units() == text.code_units()
}

fn test_source_unchecked_ascii_retains_short_and_long_storage_and_raw_wtf8_bytes() {
	limit := int(sizeof(voidptr)) - int(sizeof(u8))
	for length in [0, 1, limit, limit + 1] {
		input := []u8{len: length, init: 0xff}
		text := utf16_string_from_ascii_without_validation(input)
		assert text.has_ascii_storage()
		assert text.has_short_ascii_storage() == (length <= limit)
		assert text.str().bytes() == input
		assert text.code_units().len == length
		assert text.to_well_formed().str() == text.str()
	}
	bytes := [u8(0xed), 0xa0, 0x80, 0, 0xff, 0xe2, 0x82]
	text := utf16_string_from_ascii_without_validation(bytes)
	assert text.str().bytes() == bytes
	assert text.code_units().len == bytes.len
	assert text.code_units() != utf16_string_from_utf8_without_validation(bytes.bytestr()).code_units()
}

fn test_source_unchecked_ascii_stale_internal_units_cannot_reuse_raw_bytes() {
	mut text := utf16_string_from_ascii_without_validation([u8(0xff), 0])
	text.data[0] = 0xd800
	assert !text.has_ascii_storage()
	assert !text.has_short_ascii_storage()
	assert text.str().bytes() == [u8(0xed), 0xa0, 0x80, 0]
	copy := text.clone()
	assert !copy.has_ascii_storage()
	assert copy.str() == text.str()
	text.data[0] = u16(`A`)
	assert text.has_ascii_storage()
	assert text.str() == 'A\x00'
	assert text.clone().str() == text.str()
	// IPC ASCII construction retains its own validating boundary.
	if _ := utf16_string_from_code_units_with_storage([u16(255)], true) {
		assert false
	}
}
