module css

fn test_ident_escape_entry_preserves_cursor_at_non_escape_terminators() {
	for prefix in ['', 'β\n😀'] {
		for name in ['', 'name', '--β😀', 'long'.repeat(64)] {
			for terminator in [' ', '\t', '\n', ';', ':', '{', '}', '/', '(', ')', '.', '+', '"', '\u0000'] {
				mut tokenizer := Tokenizer.new(prefix + name + terminator + 'tail')
				for _ in prefix.runes_iterator() { _ = tokenizer.next_code_point() }
				value, escaped := tokenizer.consume_an_ident_sequence_with_escape_flag()
				assert value == name
				assert !escaped
				assert tokenizer.index == prefix.runes().len + name.runes().len
				assert tokenizer.current_byte_offset() == prefix.len + name.len
				assert tokenizer.next_code_point() == u32(terminator.runes()[0])
				assert tokenizer.prev_index == prefix.runes().len + name.runes().len
				tokenizer.input_arena.release()
			}
		}
	}
}

fn test_ident_escape_entry_preserves_escape_and_eof_spelling() {
	for source in ['plain', 'β😀', '--custom', 'foo\\62 ar', 'a\\😀', 'a\\0 ', 'a\\'] {
		tokens := Tokenizer.tokenize(source, 'utf-8')
		assert tokens.len == 2
		assert tokens[0].is(.ident)
		assert tokens[0].original_source_text() == source
		assert tokens[0].start_position() == TokenPosition{line: 0, column: 0}
		assert tokens[0].end_position() == TokenPosition{line: 0, column: uint(source.runes().len)}
		assert tokens[1].is(.end_of_file)
		assert tokens[1].start_position() == tokens[0].end_position()
		assert tokens[1].end_position() == tokens[0].end_position()
	}
	tokens := Tokenizer.tokenize('a\\\nb', 'utf-8')
	assert tokens.len == 5
	assert tokens[0].ident() == 'a'
	assert tokens[1].is(.delim) && tokens[1].delim() == `\\`
	assert tokens[2].is(.whitespace)
	assert tokens[3].ident() == 'b'
	assert tokens[3].start_position() == TokenPosition{line: 1, column: 0}
}
