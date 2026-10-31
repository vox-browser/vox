module css

fn test_token_delimiter_returns_every_ascii_code_point() {
	for code_point in 0 .. 128 {
		token := Token.create_delim(u32(code_point), rune(code_point).str())
		assert token.delim() == u32(code_point)
		assert ComponentValue.from_token(token).is_delim(u32(code_point))
		assert !ComponentValue.from_token(token).is_delim(u32(code_point + 1))
	}
}

fn test_token_delimiter_preserves_unicode_and_empty_values() {
	for code_point in [u32(0x80), 0x3b2, 0x4e2d, 0x1f600, 0x10ffff] {
		token := Token.create_delim(code_point, 'original spelling')
		assert token.delim() == code_point
		assert ComponentValue.from_token(token).is_delim(code_point)
	}
	assert (Token{ type_: .delim }).delim() == 0
	assert !ComponentValue.from_token(Token.create_ident('!', '!')).is_delim(u32(`!`))
}

fn test_token_delimiter_keeps_decoder_semantics_for_public_value_storage() {
	// Token.value is public: callers can supply byte strings that the tokenizer
	// would not produce. Preserve the first-rune behavior for those values too.
	for byte in 0x80 .. 256 {
		value := [u8(byte)].bytestr()
		token := Token{ type_: .delim, value: value }
		assert token.delim() == u32(value.runes()[0])
	}
	for value in ['abc', 'a😀', '😀abc', 'a\x00b', [u8(0xe2), 0x82].bytestr(),
		[u8(`a`), 0xff].bytestr()] {
		token := Token{ type_: .delim, value: value }
		assert token.delim() == u32(value.runes()[0])
	}
}
