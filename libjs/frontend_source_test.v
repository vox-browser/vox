module libjs

fn test_frontend_source_utf16_preserves_ascii_and_unicode_code_units() {
	assert source_utf16('').len == 0
	assert source_utf16('\x00\t\r\n\x1f ~\x7f') == [u16(0), 9, 13, 10, 31, 32, 126, 127]
	assert source_utf16('aé𐐀z') == [u16(0x61), 0xe9, 0xd801, 0xdc00, 0x7a]
	assert source_utf16('prefix\xffsuffix') == utf16('prefix\xffsuffix')
}
