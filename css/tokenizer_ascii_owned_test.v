module css

import encoding as text_encoding

fn owned_ascii_css_oracle(input string, label string) string {
	decoder := text_encoding.TextDecoder.construct(label, text_encoding.TextDecoderOptions{}) or {
		panic(err)
	}
	return decoder.decode(input.bytes(), text_encoding.TextDecodeOptions{}) or { panic(err) }
}

fn test_ascii_css_owned_destination_preserves_all_controls_and_aliases() {
	mut bytes := []u8{}
	for value in 0 .. 128 {
		bytes << u8(value)
	}
	input := bytes.bytestr()
	for label in ['utf-8', ' UTF8\t', 'unicode-1-1-utf-8', '  UTF-8\r\n'] {
		decoded := decode_css_input(input, label)
		assert decoded == input
		assert decoded == owned_ascii_css_oracle(input, label)
		assert decoded.str != input.str
		assert unsafe { decoded.str[decoded.len] } == 0
		assert decode_css_input('', label) == ''
	}
}

fn owned_ascii_css_from_view() string {
	payload := 'a{content:"A"}\r\n\t\u0000'.repeat(8)
	mut backing := 'start:' + payload + 'AFTER'
	view := backing.substr_unsafe(6, 6 + payload.len)
	assert unsafe { view.str[view.len] } == `A`
	decoded := decode_css_input(view, 'utf8')
	assert decoded == payload
	assert decoded.str != view.str
	assert unsafe { decoded.str[decoded.len] } == 0
	// The producer remains independently mutable and can leave scope immediately.
	unsafe {
		backing.str[6] = `Z`
	}
	assert decoded == payload
	return decoded
}

fn test_ascii_css_owned_destination_detaches_unterminated_producer_views() {
	decoded := owned_ascii_css_from_view()
	for _ in 0 .. 3 {
		gc_collect()
		assert decoded == 'a{content:"A"}\r\n\t\u0000'.repeat(8)
		assert unsafe { decoded.str[decoded.len] } == 0
	}
}

fn test_ascii_css_owned_destination_keeps_ascii_legacy_and_utf16_interpretation() {
	for label in ['utf-16le', 'utf-16be'] {
		input := if label == 'utf-16le' { [u8(`A`), 0, `B`, 0].bytestr() } else { [
				u8(0),
				`A`,
				0,
				`B`,
			].bytestr() }
		assert decode_css_input(input, label) == 'AB'
		assert decode_css_input(input, label) == owned_ascii_css_oracle(input, label)
		assert decode_css_input(input, label) != input
	}
	japanese := [u8(0x1b), `$`, `B`, `$`, `"`, 0x1b, `(`, `B`].bytestr()
	assert decode_css_input(japanese, 'iso-2022-jp') == 'あ'
	assert decode_css_input(japanese, 'iso-2022-jp') == owned_ascii_css_oracle(japanese,
		'iso-2022-jp')
	for label in ['windows-1252', 'x-user-defined', 'koi8-r', 'shift_jis'] {
		assert decode_css_input('A\t\r\n\u0000Z', label) == owned_ascii_css_oracle('A\t\r\n\u0000Z',
			label)
	}
}

fn test_ascii_css_owned_destination_leaves_non_ascii_and_bom_decoding_intact() {
	for prefix in ['', 'a'.repeat(256)] {
		for tail in ['\ufeffZ', 'β中😀', [u8(0xe2), 0x82].bytestr(),
			[u8(0xed), 0xa0, 0x80].bytestr(), [u8(0xff)].bytestr()] {
			input := prefix + tail
			assert decode_css_input(input, 'utf-8') == owned_ascii_css_oracle(input, 'utf-8')
		}
	}
	assert decode_css_input('\ufeff\ufeffa', 'utf-8') == '\ufeffa'
	assert decode_css_input('a\ufeff', 'utf-8') == 'a\ufeff'
}

fn test_ascii_css_owned_destination_keeps_filtering_and_token_source_positions() {
	assert filter_code_points('a\r\nb\fc\u0000d\ne', 'utf8') == 'a\nb\nc�d\ne'
	tokens := Tokenizer.tokenize('first\r\nsecond\fthird\u0000last', 'utf8')
	assert tokens[0].ident() == 'first'
	assert tokens[2].ident() == 'second'
	assert tokens[2].start_position().line == 1
	assert tokens[4].ident() == 'third�last'
	assert tokens[4].start_position().line == 2
	gc_collect()
	assert tokens[4].original_source_text() == 'third�last'
}
