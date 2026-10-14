module css

import encoding as text_encoding

fn assert_css_decode_matches_text_decoder(input string, label string) {
	decoder := text_encoding.TextDecoder.construct(label, text_encoding.TextDecoderOptions{}) or {
		panic(err)
	}
	expected := decoder.decode(input.bytes(), text_encoding.TextDecodeOptions{}) or { panic(err) }
	assert decode_css_input(input, label) == expected
}

fn test_css_utf8_destination_preserves_valid_scalars_and_ascii_bytes() {
	mut bytes := []u8{}
	for byte in 0 .. 128 {
		bytes << u8(byte)
	}
	for input in ['', bytes.bytestr(), 'β中😀', '\ud000\ud7ff\ue000\ufffd', '\ufeff\ufeffa'] {
		assert_css_decode_matches_text_decoder(input, 'utf-8')
	}
	assert decode_css_input('\ufeff\ufeffa', 'utf-8') == '\ufeffa'
	assert decode_css_input('β中😀', 'utf-8') == 'β中😀'
}

fn test_css_utf8_destination_preserves_malformed_and_truncated_input() {
	for byte in 0 .. 256 {
		assert_css_decode_matches_text_decoder([u8(byte)].bytestr(), 'utf-8')
		for lead in [u8(0xc2), 0xdf, 0xe0, 0xed, 0xef, 0xf0, 0xf4] {
			assert_css_decode_matches_text_decoder([lead, u8(byte)].bytestr(), 'utf-8')
			assert_css_decode_matches_text_decoder([lead, u8(byte), 0x80, `X`].bytestr(), 'utf-8')
		}
	}
	assert decode_css_input([u8(0xed), 0xa0, 0x80].bytestr(), 'utf-8') == '���'
	assert decode_css_input([u8(0xf0), 0x9f, 0x98].bytestr(), 'utf-8') == '�'
}

fn test_css_utf8_destination_keeps_label_selection_and_utf16_bom_rules() {
	for label in [' UTF-8\t', 'unicode-1-1-utf-8', 'utf8'] {
		assert_css_decode_matches_text_decoder('\ufeffβ😀', label)
	}
	for label in ['utf-16', 'UTF-16LE', 'unicodefeff', 'utf-16be', 'unicodefffe'] {
		for input in [
			[u8(0xff), 0xfe, 0x3d, 0xd8, 0, 0xde, 0, 0],
			[u8(0xfe), 0xff, 0xd8, 0x3d, 0xde, 0, 0, 0],
			[u8(0), 0xd8, `X`, 0, 0],
			[u8(0), 0xdc],
			[u8(0xff)],
		] {
			assert_css_decode_matches_text_decoder(input.bytestr(), label)
		}
	}
}

fn test_css_utf8_destination_keeps_legacy_decoders() {
	mut bytes := []u8{}
	for byte in 0 .. 256 {
		bytes << u8(byte)
	}
	for label in ['windows-1252', 'latin1', 'x-user-defined', 'koi8-r'] {
		assert_css_decode_matches_text_decoder(bytes.bytestr(), label)
	}
	for input in [[u8(0x82), 0xa0, 0xa6], [u8(0x82)], [u8(0x82), ` `, 0xff],
		[]u8{}] {
		assert_css_decode_matches_text_decoder(input.bytestr(), 'shift_jis')
	}
}

fn test_css_utf8_destination_uses_a_fresh_one_shot_owner() {
	for _ in 0 .. 4 {
		assert decode_css_input('\ufeffa', 'utf-8') == 'a'
		assert decode_css_input([u8(0xe2), 0x82].bytestr(), 'utf-8') == '�'
		assert decode_css_input('b', 'utf-8') == 'b'
		assert decode_css_input([u8(0xff), 0xfe, `c`, 0].bytestr(), 'utf-16le') == 'c'
	}
}
