module css

fn test_tokenizer_input_arena_tracks_utf8_offsets_and_releases_owned_storage() {
	mut arena := TokenizerInputArena.new('Aβ中😀\n')
	assert arena.len == 5
	for i, expected in [u32(`A`), u32(`β`), u32(`中`), u32(`😀`), u32(`\n`)] {
		assert unsafe { arena.code_points[i] } == expected
		assert unsafe { arena.byte_offsets[i] } == [0, 1, 3, 6, 10][i]
	}
	assert arena.storage != unsafe { nil }
	arena.release()
	assert arena.storage == unsafe { nil }
	assert arena.len == 0
	arena.release()
}

fn test_tokenizer_arena_preserves_filtered_source_positions_and_eof() {
	tokens := Tokenizer.tokenize('β\r\n中\u0000😀', 'utf-8')
	assert tokens[0].ident() == 'β'
	assert tokens[0].end_position().column == 1
	assert tokens[1].original_source_text() == '\n'
	assert tokens[2].ident() == '中�😀'
	assert tokens[2].start_position().line == 1
	assert tokens[2].start_position().column == 0
	assert tokens[2].end_position().column == 3
	assert tokens.last().is(.end_of_file)
	assert Tokenizer.tokenize('', 'utf-8').len == 1
	mut empty := TokenizerInputArena.new('')
	assert empty.storage == unsafe { nil }
	empty.release()
}
