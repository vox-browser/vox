module libjs

// The one-pass conversion agrees with the rune-based one for ASCII,
// two-, three- and four-byte sequences, boundaries and malformed input.
fn test_utf16_matches_rune_conversion() {
	for text in ['', 'abc', 'é', 'aé€😀z', 'ÿࠀ￿', 'x\U0010ffff', '😀😀', 'end é'] {
		assert utf16(text) == utf16_from_runes(text), text
	}
	for bytes in [[u8(0xff)], [u8(0xc3)], [u8(0xc3), 0x41], [u8(0xe2), 0x82], [u8(0xed), 0xa0, 0x80],
		[u8(0xc0), 0xaf], [u8(0xf4), 0x90, 0x80, 0x80], [u8(0x61), 0xe2, 0x82, 0xac, 0x80], [u8(0xf0), 0x9f, 0x98]] {
		text := bytes.bytestr()
		assert utf16(text) == utf16_from_runes(text), '${bytes}'
	}
	long := 'const x = "é";\n'.repeat(1000)
	assert utf16(long) == utf16_from_runes(long)
	converted := utf16_string('aé😀')
	assert converted.data == [u16(0x61), 0xe9, 0xd83d, 0xde00] && converted.data.cap >= converted.data.len
}
