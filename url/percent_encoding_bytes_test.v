module url

import platform

fn test_percent_encoding_bytes_matches_all_ascii_bytes_and_sets() {
	sets := [PercentEncodeSet.c0_control, .fragment, .query, .special_query, .path, .userinfo,
		.component, .application_x_www_form_urlencoded, .encode_uri]
	for set in sets {
		for plus in [false, true] {
			for b in 0 .. 128 {
				input := [u8(b)].bytestr()
				expected := if plus && b == 32 {
					'+'
				} else if code_point_is_in_percent_encode_set_scanning(u32(b), set) {
					'%${b:02X}'
				} else {
					input
				}
				assert percent_encode(input, set, plus) == expected
			}
			input := []u8{len: 128, init: u8(index)}.bytestr()
			assert percent_encode(input, set, plus) == percent_encode_runes(input, set, plus)
		}
	}
}

fn test_percent_encoding_bytes_preserves_unicode_and_malformed_decoder_behavior() {
	mut inputs := ['', 'plain', 'a b+c%/?:#', 'é漢😀', '\u007f\u0080\u07ff\u0800\ud7ff\ue000\uffff',
		'\U00010000\U0010ffff', 'prefix'.repeat(128) + '😀' + ' suffix']
	for bytes in [[u8(0x80)], [u8(0xc0), 0xaf], [u8(0xc2)], [u8(0xe2), 0x82], [u8(0xed), 0xa0,
		0x80], [u8(0xf4), 0x90, 0x80, 0x80], [u8(0xf0), 0x9f, 0x98], [u8(0xff), 0x00, 0x61],
		[u8(0xe2), 0x28, 0xa1]] {
		inputs << bytes.bytestr()
	}
	for set in [PercentEncodeSet.c0_control, .fragment, .query, .special_query, .path, .userinfo,
		.component, .application_x_www_form_urlencoded, .encode_uri] {
		for plus in [false, true] {
			for input in inputs {
				assert percent_encode(input, set, plus) == percent_encode_runes(input, set, plus)
			}
		}
	}
}

fn test_percent_encoding_bytes_outputs_own_their_storage() {
	for text in ['unchanged-ASCII', 'space and%punctuation', 'é😀'] {
		mut arena := platform.new_arena('percent encoding input')
		entry := arena.enter()
		input := text.clone()
		arena.leave(entry)
		encoded := percent_encode(input, .component, true)
		assert encoded == percent_encode_runes(text, .component, true)
		unsafe { input.str[0] = `!` }
		assert encoded == percent_encode_runes(text, .component, true)
		arena.release()
		assert encoded == percent_encode_runes(text, .component, true)
	}
}

fn test_percent_encoding_bytes_random_valid_scalar_sequences() {
	mut state := u32(0x41534349)
	for sample in 0 .. 128 {
		mut runes := []rune{}
		for _ in 0 .. 17 {
			state = state * 1664525 + 1013904223
			cp := state % 0x110000
			if cp < 0xd800 || cp > 0xdfff { runes << rune(cp) }
		}
		input := runes.string()
		set := [PercentEncodeSet.c0_control, .fragment, .query, .special_query, .path, .userinfo,
			.component, .application_x_www_form_urlencoded, .encode_uri][sample % 9]
		assert percent_encode(input, set, sample % 2 == 0) == percent_encode_runes(input, set, sample % 2 == 0)
	}
}
