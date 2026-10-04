module libjs

fn test_source_unvalidated_utf8_boundary_retains_wtf8_code_units_and_storage() {
	units := [u16(`n`), 0xd800, 0, 0xdc00, 0xd83d, 0xde00, u16(`x`)]
	text := utf16_string_from_code_units(units)
	decoded := utf16_string_from_utf8_without_validation(text.str())
	assert decoded.code_units() == units
	assert !decoded.has_ascii_storage()
	assert utf16_string_from_utf8_without_validation('abc\x00').code_units() == [
		u16(`a`),
		u16(`b`),
		u16(`c`),
		0,
	]
	assert utf16_string_from_utf8_without_validation('abc\x00').has_ascii_storage()
	assert utf16_string_from_utf8_without_validation('').has_ascii_storage()
	// The existing generic adapter's behavior is intentionally unchanged.
	assert utf16(text.str()) != units
}

fn test_source_unvalidated_utf8_fallback_matches_native_ak_iterator_error_and_advance_rules() {
	assert utf16_string_from_utf8_without_validation([u8(0xff), 0xfe].bytestr()).code_units() == [
		u16(0xfffd),
		0xfffd,
	]
	assert utf16_string_from_utf8_without_validation([u8(0xe2), 0x28, 0xa1].bytestr()).code_units() == [
		u16(0xfffd),
		0x28,
		0xfffd,
	]
	assert utf16_string_from_utf8_without_validation([u8(0xe2), 0x82].bytestr()).code_units() == [
		u16(0xfffd),
		0xfffd,
	]
	assert utf16_string_from_utf8_without_validation([u8(0xf0), 0x9f, 0x98].bytestr()).code_units() == [
		u16(0xfffd),
		0xfffd,
		0xfffd,
	]
	assert utf16_string_from_utf8_without_validation([u8(0xf4), 0x90, 0x80, 0x80].bytestr()).code_units() == [u16(0xfffd)]
	assert utf16_string_from_utf8_without_validation([u8(0xf8), 0x80].bytestr()).code_units() == [
		u16(0xfffd),
		0xfffd,
	]
	// AK's unvalidated fallback does not apply UTF-8 shortest-form rules.
	overlong := utf16_string_from_utf8_without_validation([u8(0xc0), 0xaf].bytestr())
	assert overlong.code_units() == [u16(`/`)]
	assert !overlong.has_ascii_storage()
	assert utf16_string_from_utf8_without_validation([u8(0xe0), 0x80, 0x80].bytestr()).code_units() == [u16(0)]
}

fn test_source_ascii_lowercase_preserves_raw_utf16_units_and_original_owner() {
	text := utf16_string_from_code_units([u16(`A`), u16(`Z`), 0xd800, 0, 0xdc00, 0x00c9, u16(`a`),
		u16(`0`)])
	lower := text.to_ascii_lowercase()
	assert lower.code_units() == [u16(`a`), u16(`z`), 0xd800, 0, 0xdc00, 0x00c9, u16(`a`), u16(`0`)]
	assert text.code_units()[0] == u16(`A`)
	mut returned := lower.code_units()
	returned[0] = 0
	assert lower.code_units()[0] == u16(`a`)
}
