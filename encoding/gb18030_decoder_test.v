module encoding

fn gb18030_decode(label string, input []u8) string {
	decoder := TextDecoder.construct(label, TextDecoderOptions{}) or { panic(err) }
	return decoder.decode(input, TextDecodeOptions{}) or { panic(err) }
}

fn test_gb18030_and_gbk_decode_the_encoding_standard_vectors() {
	cases := [
		[[u8(115)], 's'.bytes()],
		[[u8(0x80)], '€'.bytes()],
		[[u8(0xFF)], '�'.bytes()],
		[[u8(0x81)], '�'.bytes()],
		[[u8(0x81), 0x28], '�('.bytes()],
		[[u8(0x81), 0x40], '丂'.bytes()],
		[[u8(0x81), 0x7F], '�\u007F'.bytes()],
		[[u8(0x81), 0xFE], '侢'.bytes()],
		[[u8(0x81), 0xFF], '�'.bytes()],
		[[u8(0xFE), 0xFE], ''.bytes()],
		[[u8(0x81), 0x30], '�'.bytes()],
		[[u8(0x81), 0x30, 0xFE], '�'.bytes()],
		[[u8(0x81), 0x30, 0xFF], '�0�'.bytes()],
		[[u8(0x81), 0x30, 0xFE, 0x29], '�0�)'.bytes()],
		[[u8(0xFE), 0x39, 0xFE, 0x39], '�'.bytes()],
		[[u8(0x81), 0x35, 0xF4, 0x36], 'Ḿ'.bytes()],
		[[u8(0x81), 0x35, 0xF4, 0x37], ''.bytes()],
		[[u8(0x84), 0x31, 0xA4, 0x39], '￿'.bytes()],
		[[u8(0x84), 0x31, 0xA5, 0x30], '�'.bytes()],
		[[u8(0x90), 0x30, 0x81, 0x30], '\U00010000'.bytes()],
		[[u8(0xE3), 0x32, 0x9A, 0x35], '\U0010FFFF'.bytes()],
		[[u8(0xE3), 0x32, 0x9A, 0x36], '�'.bytes()],
		[[u8(0xA1), 0xAD], '…'.bytes()],
		[[u8(0xA6), 0xD9], '︐'.bytes()],
	]
	for label in ['gb18030', 'gbk'] {
		for item in cases {
			assert gb18030_decode(label, item[0]).bytes() == item[1], '${label} ${item[0]}'
		}
	}
}

fn test_gb18030_streaming_keeps_a_split_sequence_and_fatal_rejects_errors() {
	mut decoder := TextDecoder.construct('gb18030', TextDecoderOptions{}) or { panic(err) }
	mut text := decoder.decode([u8(0x41), 0x90, 0x30], TextDecodeOptions{ stream: true }) or { panic(err) }
	text += decoder.decode([u8(0x81)], TextDecodeOptions{ stream: true }) or { panic(err) }
	text += decoder.decode([u8(0x30), 0x81], TextDecodeOptions{}) or { panic(err) }
	assert text == 'A\U00010000�'
	assert decoder.decode([u8(0x81), 0x40], TextDecodeOptions{}) or { panic(err) } == '丂'
	fatal := TextDecoder.construct('gbk', TextDecoderOptions{ fatal: true }) or { panic(err) }
	if _ := fatal.decode([u8(0x81), 0x7F], TextDecodeOptions{}) {
		assert false, 'a fatal decoder must reject an invalid trail byte'
	}
	assert decode_bytes_for_encoding([u8(0x80), 0x41], 'gbk', false) or { panic(err) } == '€A'
}
