module css

fn test_bulk_css_probes_respect_unaligned_unterminated_view_boundaries() {
	for start in 0 .. 17 {
		for length in [0, 1, 7, 8, 15, 16, 31, 32, 33, 63, 64, 65, 95, 96, 97] {
			mut bytes := []u8{len: start + length + 1, init: u8(0xff)}
			for index in start .. start + length { bytes[index] = `a` }
			backing := bytes.bytestr()
			view := backing.substr_unsafe(start, start + length)
			assert css_input_is_ascii(view)
			assert !css_input_needs_filtering(view)
			// A NUL just beyond the logical end is not tokenizer input either.
			unsafe { backing.str[start + length] = 0 }
			assert !css_input_needs_filtering(view)
		}
	}
}

fn test_bulk_css_probes_classify_every_byte_at_word_and_tail_boundaries() {
	for index in [0, 1, 7, 8, 15, 16, 23, 24, 31, 32, 63, 64, 95] {
		for byte in 0 .. 256 {
			mut bytes := []u8{len: 96, init: `a`}
			bytes[index] = u8(byte)
			input := bytes.bytestr()
			assert css_input_is_ascii(input) == (byte < 128)
			assert css_input_needs_filtering(input) == (byte in [0, 12, 13])
		}
	}
}

fn test_bulk_css_probes_keep_filtering_and_unicode_decoding() {
	prefix := 'x'.repeat(64)
	assert filter_code_points(prefix + 'a\r\nb\fc\u0000d', 'utf-8')
		== prefix + 'a\nb\nc�d'
	assert filter_code_points(prefix + 'é尾🙂', 'utf-8') == prefix + 'é尾🙂'
	assert decode_css_input(prefix + [u8(0x80)].bytestr(), 'windows-1252') == prefix + '€'
}
