module css

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn test_unescaped_identifier_shares_one_terminated_source_spelling() {
	tokens := Tokenizer.tokenize('plain β 中😀 --custom -MixedCase foo\\62 ar \\0\\1', 'utf-8')
	identifiers := tokens.filter(it.is(.ident))
	assert identifiers.map(it.ident()) == ['plain', 'β', '中😀', '--custom', '-MixedCase',
		'foobar', '�\x01']
	for index, token in identifiers {
		if index < 5 {
			assert token.ident().str == token.original_source_text().str
		} else {
			assert token.ident() != token.original_source_text()
		}
		assert unsafe { token.ident().str[token.ident().len] } == 0
		assert unsafe { token.original_source_text().str[token.original_source_text().len] } == 0
	}
	assert identifiers[5].original_source_text() == 'foo\\62 ar'
	// Escapes can preserve the total byte length while still changing the text.
	assert identifiers[6].ident().len == identifiers[6].original_source_text().len
}

fn test_single_byte_token_spellings_are_stable_and_terminated() {
	for byte in 0x20 .. 0x7f {
		source := rune(byte).str()
		mut first := Tokenizer.new(source)
		defer { first.input_arena.release() }
		first.index = first.input_arena.len
		mut second := Tokenizer.new(source.clone())
		defer { second.input_arena.release() }
		second.index = second.input_arena.len
		spelling := first.input_since(0)
		assert spelling == source
		assert spelling.str == second.input_since(0).str
		assert unsafe { spelling.str[spelling.len] } == 0
	}
	for source in ['\n', '\t'] {
		mut tokenizer := Tokenizer.new(source)
		defer { tokenizer.input_arena.release() }
		tokenizer.index = tokenizer.input_arena.len
		assert tokenizer.input_since(0) == source
		assert unsafe { tokenizer.input_since(0).str[1] } == 0
	}
}

fn retained_token_spellings() []Token {
	return Tokenizer.tokenize('ignored '.repeat(4096) + 'a{--name:β;content:"x"} foo\\62 ar',
		'utf-8')
}

fn test_delimiter_sharing_preserves_the_requested_code_point() {
	for byte in 0 .. 128 {
		spelling := rune(byte).str()
		token := Token.create_delim(u32(byte), spelling)
		assert token.value == spelling
		assert token.value.str == token.original_source_text().str
		assert unsafe { token.value.str[token.value.len] } == 0
	}
	for code_point in [u32(`!`), u32(`β`), u32(`😀`)] {
		token := Token.create_delim(code_point, 'different source')
		assert token.value == rune(code_point).str()
		assert token.original_source_text() == 'different source'
	}
}

fn test_shared_token_spellings_survive_their_producer_and_collections() {
	tokens := retained_token_spellings()
	for _ in 0 .. 3 {
		$if gcboehm ? { C.GC_gcollect() }
		last := tokens[tokens.len - 2]
		assert last.ident() == 'foobar'
		assert last.original_source_text() == 'foo\\62 ar'
		for token in tokens {
			source := token.original_source_text()
			assert unsafe { source.str[source.len] } == 0
			if token.is(.ident) && token.ident() == '--name' {
				assert token.original_source_text() == '--name'
				assert token.ident().str == token.original_source_text().str
			}
		}
	}
}
