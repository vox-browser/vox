module dom

// run_bom_sniff / is_valid_utf8 / run_encoding_sniffing_algorithm / text_decoder_validate, translated
// from HTML::HTMLEncodingDetection + TextCodec (replacing the always-UTF-8/true stubs).
fn test_bom_sniff() {
	assert (run_bom_sniff([u8(0xEF), 0xBB, 0xBF, 0x41]) or { 'x' }) == 'UTF-8'
	assert (run_bom_sniff([u8(0xFE), 0xFF, 0x00]) or { 'x' }) == 'UTF-16BE'
	assert (run_bom_sniff([u8(0xFF), 0xFE, 0x00]) or { 'x' }) == 'UTF-16LE'
	// Fewer than 3 bytes: upstream doesn't sniff.
	if _ := run_bom_sniff([u8(0xFE), 0xFF]) {
		assert false
	}
	if _ := run_bom_sniff([u8(0x41), 0x42, 0x43]) {
		assert false
	}
}

fn test_is_valid_utf8() {
	assert is_valid_utf8('hello'.bytes())
	assert is_valid_utf8('héllo wörld — 🧐'.bytes())
	assert is_valid_utf8([]u8{}) // empty is valid
	assert !is_valid_utf8([u8(0xFF), 0xFE]) // 0xFF is never a lead byte
	assert !is_valid_utf8([u8(0xC0), 0x80]) // overlong 2-byte
	assert !is_valid_utf8([u8(0xE0), 0x80, 0x80]) // overlong 3-byte (first cont must be >= 0xA0)
	assert !is_valid_utf8([u8(0xED), 0xA0, 0x80]) // UTF-16 surrogate (first cont must be <= 0x9F)
	assert !is_valid_utf8([u8(0xC2)]) // truncated 2-byte
	assert !is_valid_utf8([u8(0xE2), 0x82]) // truncated 3-byte
}

fn test_encoding_sniffing() {
	doc := Document.create(url_about_blank())
	mime := MimeType{}
	assert run_encoding_sniffing_algorithm(doc, 'hello world'.bytes(), mime) == 'UTF-8'
	// BOM wins.
	assert run_encoding_sniffing_algorithm(doc, [u8(0xEF), 0xBB, 0xBF, 0x41], mime) == 'UTF-8'
	// Invalid UTF-8 falls back to windows-1252.
	assert run_encoding_sniffing_algorithm(doc, [u8(0x41), 0xFF, 0x42], mime) == 'windows-1252'
}

fn test_text_decoder_validate() {
	assert text_decoder_validate('ok'.bytes(), 'utf-8')
	assert !text_decoder_validate([u8(0xFF)], 'utf-8')
	assert !text_decoder_validate([u8(0xFF)], none) // default is utf-8
	// A non-UTF-8 decoder accepts any bytes (can't fail).
	assert text_decoder_validate([u8(0xFF)], 'windows-1252')
}
