module css

fn test_css_filter_preserves_ascii_controls_and_unicode_without_replacements() {
	mut bytes := []u8{}
	for byte in 1 .. 128 {
		if byte != 12 && byte != 13 {
			bytes << u8(byte)
		}
	}
	for input in ['', bytes.bytestr(), 'β中😀', '\ud000\ud7ff\ue000\ufffd'] {
		assert filter_code_points(input, 'utf-8') == input
	}
}

fn test_css_filter_replaces_each_ascii_control_between_unicode_scalars() {
	for byte in 0 .. 128 {
		input := 'β' + rune(byte).str() + '😀'
		expected := match byte {
			0 { 'β�😀' }
			12, 13 { 'β\n😀' }
			else { input }
		}
		assert filter_code_points(input, 'utf-8') == expected
	}
}

fn test_css_filter_preserves_crlf_and_repeated_carriage_return_rules() {
	inputs := ['a\r\nb', '\r\r\n\r\n\n\f', '中\r\n😀\rX', '\u0000\f\r\n']
	expected := ['a\nb', '\n\n\n\n\n', '中\n😀\nX', '�\n\n']
	for i, input in inputs {
		assert filter_code_points(input, 'utf-8') == expected[i]
	}
}

fn test_css_filter_probes_decoded_legacy_and_utf16_input() {
	assert filter_code_points([u8(0x80), 13, 10, 0].bytestr(), 'windows-1252') == '€\n�'
	// BOM, U+D000, CRLF, a surrogate pair for U+1F600, and NUL.
	utf16 := [u8(0xff), 0xfe, 0, 0xd0, 13, 0, 10, 0, 0x3d, 0xd8, 0, 0xde, 0, 0]
	assert filter_code_points(utf16.bytestr(), 'utf-16le') == '\ud000\n😀�'
}

fn test_css_filter_keeps_decoder_replacement_and_bom_behavior() {
	assert filter_code_points([u8(0xef), 0xbb, 0xbf, `a`, 13, 10].bytestr(), 'utf-8') == 'a\n'
	assert filter_code_points([u8(0xe2), 0x82].bytestr(), 'utf-8') == '�'
	assert filter_code_points([u8(0xed), 0xa0, 0x80, 12].bytestr(), 'utf-8') == '���\n'
}
