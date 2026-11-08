module indexeddb

fn test_string_keys_and_schema_names_compare_raw_utf16_including_unpaired_surrogates() {
	high := [u8(0xed), 0xa0, 0x80].bytestr()
	low := [u8(0xed), 0xb0, 0x80].bytestr()
	assert utf16_code_units(high) == [u16(0xd800)]
	assert utf16_code_units(low) == [u16(0xdc00)]
	assert compare_utf16_code_units(high, '𝄞') < 0
	assert compare_utf16_code_units('𝄞', low) < 0
	assert compare_utf16_code_units(low, '水') > 0
	mut names := ['\ufffd', low, '𝄞', high, '\x00', '水', '']
	sort_name_list(mut names)
	assert names == ['', '\x00', '水', high, '𝄞', low, '\ufffd']
}
