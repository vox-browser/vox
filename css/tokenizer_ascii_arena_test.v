module css

fn test_tokenizer_ascii_arena_preserves_every_ascii_code_point() {
	mut bytes := []u8{cap: 128}
	for byte in 0 .. 128 {
		bytes << u8(byte)
	}
	mut arena := TokenizerInputArena.new(bytes.bytestr())
	assert arena.len == 128
	for offset in 0 .. 128 {
		assert unsafe { arena.code_points[offset] } == u32(offset)
		assert unsafe { arena.byte_offsets[offset] } == offset
	}
	arena.release()
	assert arena.storage == unsafe { nil }
	assert arena.len == 0
}

fn test_tokenizer_ascii_arena_keeps_unicode_fallback_offsets() {
	for input in ['αbody { color: red; }', 'body { color: red; }😀', 'aβ中😀z'] {
		mut arena := TokenizerInputArena.new(input)
		mut offset := 0
		mut index := 0
		for expected in input.runes_iterator() {
			assert unsafe { arena.code_points[index] } == u32(expected)
			assert unsafe { arena.byte_offsets[index] } == offset
			offset += utf8_char_len(input[offset])
			index++
		}
		assert arena.len == index
		arena.release()
	}
}

fn test_tokenizer_ascii_arena_filters_before_selecting_input_path() {
	// NUL replacement changes an otherwise ASCII source into Unicode. CRLF and
	// form feed keep the byte path while retaining filtered source coordinates.
	tokens := Tokenizer.tokenize('a\r\nb\fc\u0000d', 'utf-8')
	assert tokens[0].ident() == 'a'
	assert tokens[1].original_source_text() == '\n'
	assert tokens[2].ident() == 'b'
	assert tokens[2].start_position().line == 1
	assert tokens[3].original_source_text() == '\n'
	assert tokens[4].ident() == 'c�d'
	assert tokens[4].start_position().line == 2
	assert tokens[4].end_position().column == 3
	assert tokens.last().is(.end_of_file)
}
