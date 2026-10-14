module css

import encoding as text_encoding
import strings

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn reference_css_input_decoding(input string, label string) string {
	decoder := text_encoding.TextDecoder.construct(label, text_encoding.TextDecoderOptions{}) or {
		panic(err)
	}
	return decoder.decode(input.bytes(), text_encoding.TextDecodeOptions{}) or { panic(err) }
}

fn test_ascii_css_decoding_preserves_every_byte_and_reuses_the_input() {
	mut bytes := []u8{}
	for value in 0 .. 128 {
		bytes << u8(value)
	}
	input := bytes.bytestr()
	decoded := decode_css_input(input, 'utf-8')
	assert decoded == reference_css_input_decoding(input, 'utf-8')
	assert decoded.str == input.str
	assert decode_css_input('', 'utf-8') == ''
	assert filter_code_points('a\r\nb\fc\u0000d\ne', 'utf-8') == 'a\nb\nc�d\ne'
	tokens := Tokenizer.tokenize('first\r\nsecond\fthird\u0000last', 'utf-8')
	assert tokens[0].ident() == 'first'
	assert tokens[2].ident() == 'second'
	assert tokens[4].ident() == 'third�last'
	assert tokens[4].start_position().line == 2
}

fn test_non_ascii_css_keeps_decoder_bom_unicode_and_replacement_behavior() {
	inputs := ['β 中😀', '\xef\xbb\xbfa{}', '\xef\xbb\xbf\xef\xbb\xbfa{}',
		[u8(0xc0), 0xaf, 0x41].bytestr(), [u8(0xe2), 0x82].bytestr(),
		[u8(0xed), 0xa0, 0x80].bytestr(), [u8(0xf4), 0x90, 0x80, 0x80].bytestr()]
	for input in inputs {
		assert decode_css_input(input, 'utf-8') == reference_css_input_decoding(input, 'utf-8')
	}
	assert decode_css_input('\xef\xbb\xbfa{}', 'utf-8') == 'a{}'
	assert decode_css_input('\xef\xbb\xbf\xef\xbb\xbfa{}', 'utf-8') == '\ufeffa{}'
}

fn test_css_decoding_fast_path_does_not_override_other_encodings_or_labels() {
	for label in ['UTF-8', 'utf8', ' utf-8 ', 'windows-1252', 'iso-8859-1', 'shift_jis'] {
		input := 'body { color: red }\n'
		assert decode_css_input(input, label) == reference_css_input_decoding(input, label)
	}
	for label in ['utf-16le', 'utf-16be'] {
		input := [u8(0x41), 0, 0x42, 0].bytestr()
		assert decode_css_input(input, label) == reference_css_input_decoding(input, label)
		assert decode_css_input(input, label) != input
	}
	input := [u8(0x80), 0xe9].bytestr()
	assert decode_css_input(input, 'windows-1252') == '€é'
}

fn retained_ascii_css_tokens() []Token {
	mut builder := strings.new_builder(4096)
	builder.write_string('ignored '.repeat(512))
	builder.write_string('remembered')
	return Tokenizer.tokenize(builder.str(), 'utf-8')
}

fn test_ascii_css_token_spellings_survive_their_input_producer_and_collection() {
	tokens := retained_ascii_css_tokens()
	for _ in 0 .. 3 {
		$if gcboehm ? { C.GC_gcollect() }
		last := tokens[tokens.len - 2]
		assert last.ident() == 'remembered'
		assert last.original_source_text() == 'remembered'
		assert unsafe { last.ident().str[last.ident().len] } == 0
	}
}
