module css

fn test_tokenizer_offset_table_alignment_preserves_odd_and_even_utf8_inputs() {
	for seed in ['x', 'é', '中', '😀', 'éx', '中ab', '😀abc'] {
		for length in 1 .. 66 {
			input := seed.repeat(length)
			mut arena := TokenizerInputArena.new(input)
			assert uint(arena.byte_offsets) % sizeof(int) == 0, '${seed}, ${length}'
			assert uint(arena.code_points) % sizeof(u32) == 0
			mut offset := 0
			mut count := 0
			for point in input.runes_iterator() {
				assert unsafe { arena.byte_offsets[count] } == offset
				assert unsafe { arena.code_points[count] } == u32(point)
				offset += utf8_char_len(input[offset])
				count++
			}
			assert arena.len == count
			arena.release()
			assert arena.storage == unsafe { nil }
		}
	}
}
