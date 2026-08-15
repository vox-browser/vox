module encoding

fn test_utf8_bom() {
	assert bom_sniff([u8(0xEF), 0xBB, 0xBF])? == 'UTF-8'
	// Trailing data after the BOM is ignored.
	assert bom_sniff([u8(0xEF), 0xBB, 0xBF, 0x41, 0x42])? == 'UTF-8'
}

fn test_utf16be_bom() {
	assert bom_sniff([u8(0xFE), 0xFF])? == 'UTF-16BE'
	assert bom_sniff([u8(0xFE), 0xFF, 0x00, 0x41])? == 'UTF-16BE'
}

fn test_utf16le_bom() {
	assert bom_sniff([u8(0xFF), 0xFE])? == 'UTF-16LE'
	assert bom_sniff([u8(0xFF), 0xFE, 0x41, 0x00])? == 'UTF-16LE'
	// The two UTF-16 BOMs are distinguished by byte order.
	assert bom_sniff([u8(0xFF), 0xFE])? != bom_sniff([u8(0xFE), 0xFF])?
}

fn test_no_bom_returns_none() {
	assert bom_sniff([]u8{}) == none
	assert bom_sniff([u8(0x41)]) == none // one byte is too short
	assert bom_sniff([u8(0x41), 0x42, 0x43]) == none // plain ASCII
}

fn test_incomplete_or_wrong_bom_returns_none() {
	// An 0xEF start needs the full three-byte sequence.
	assert bom_sniff([u8(0xEF), 0xBB]) == none // only two bytes
	assert bom_sniff([u8(0xEF), 0xBB, 0x00]) == none // wrong third byte
	assert bom_sniff([u8(0xEF), 0x00, 0xBF]) == none // wrong second byte
	// The two-byte BOMs need the exact second byte.
	assert bom_sniff([u8(0xFE), 0x00]) == none
	assert bom_sniff([u8(0xFF), 0x00]) == none
}
